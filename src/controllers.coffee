#this controller is responsible for the initial authorisation of the app

app.controller 'AuthController', ($scope, $rootScope, $q, twitterService) ->

    self = this

    twitterService.initialise()

    self.getUser = () ->
        return twitterService.user

    self.twitterReady = () ->
        return twitterService.twitterReady()

    #sends data from the Twitter service to the other controllers through $root.$broadcast
    self.authClick = () ->

        if !twitterService.twitterReady()
            twitterService.connectToTwitter().then () ->
                if twitterService.twitterReady()
                    twitterService.getContacts().then (data) ->
                        $rootScope.$broadcast('event:contacts-loaded', data: data)
                    twitterService.getMessages().then (data) ->
                        $rootScope.$broadcast('event:messages-loaded', data: data)
        else
            twitterService.disconnectTwitter()
    @

#this controller is responsible for the inbox list as well as the 'details' window of selected messages

app.controller 'InboxController', ($scope, $rootScope, $q, twitterService, cryptoService, googleService) ->

    self = this
    self.password = ''
    self.messages = []
    self.currentMessage = null
    self.displayedMessage = null
    self.justEncrypted = false
    self.image = 'no base64 loaded'

    self.isEncrypted = (message) ->
        return cryptoService.isEncrypted(message)

    self.passwordValid = () ->
        return self.password isnt null and self.password isnt ''

    self.checkPassword = () ->

        try
            cryptoService.decryptMessage(self.password, self.currentMessage.text)
            return true
        catch e
            return false
        
    self.decryptClick = () ->

        self.errors = {}

        pw = self.password

        if self.passwordValid()
            try
                self.currentMessage.decryptText = cryptoService.decryptMessage(self.password, self.currentMessage.text)
                arr = self.currentMessage.decryptText.split('\n')
                if arr.length > 2 and arr[arr.length-2] is '---attachment---'
                    googleService.downloadFile(arr[arr.length-1]).then (image) ->
                        encryptedImage = image
                        self.currentMessage.image = cryptoService.decryptMessage(pw, encryptedImage)
                        self.currentMessage.decryptText = arr[0..-3].join('\n')
                        self.currentMessage.showImage = true

            catch error
                console.log('You entered an incorrect password: ' + self.password)
                console.log error
                self.errors = {
                    incorrect : true
                }

            self.password = ''
        else
            console.log('You did not enter a password!')
            self.errors = {
                empty : true
            }

    self.hideDecrypted = () ->

        self.currentMessage.decryptText = null
        self.currentMessage.image = null
        self.currentMessage.showImage = false

    self.selectMessage = (message) ->
        self.currentMessage = message

    self.loadMessages = () ->

        if self.messages.length is 0

            twitterService.getMessages().then (data) ->
                console.log "getting da msgs"
                self.messages = data.filter (msg) ->
                    return self.isEncrypted(msg.text)

        else

            twitterService.getMessages(self.messages[0].id_str).then (data) ->
                #console.log data
                self.messages = data.filter (msg) ->
                    return self.isEncrypted(msg.text)
                .concat(self.messages)[0..8]


    self.loadContacts = () ->
        twitterService.getContacts().then (data) ->
            $scope.contactList = data

    self.previewMessage = (message) ->
        if message.length > 20
            return message.substring(0,20) + '...'
        else
            return message

    $rootScope.$on 'event:messages-loaded', (event, args) ->
        self.messages = args.data.filter (msg) ->
            self.isEncrypted(msg.text)

    @ # DO NOT DELETE THIS - shorthand for 'return this' - otherwise the controller object will not be returned!

#this controller is responsible for composing new messages

app.controller 'ComposeController', ($scope, $rootScope, $q, twitterService, googleService, cryptoService) ->

    self = this
    self.password = ''
    self.contacts = ''
    self.message = ''
    self.justSent = false
    self.image = {}

    self.driveAuth = () ->

        googleService.getAccessToken()

    self.getGoogleUser = () ->

        return googleService.getUser()        

    self.googleReady = () ->

        return googleService.googleReady() 

    self.makeFilter = (query) ->

        queryLower = angular.lowercase(query)

        if queryLower.substring(0,1) is '@'
            queryLower = queryLower.substring(1)
            return (user) ->
                user.screenNameLower.indexOf(queryLower) is 0
        return (user) ->
            return user.nameLower.indexOf(queryLower) is 0 or user.screenNameLower.indexOf(queryLower) is 0

    self.searchContacts = (query) ->

        if query
            return self.contacts.filter(self.makeFilter(query))
        else
            return self.contacts

    self.composeAnother = () ->
        self.justSent = false

    self.sendMessage = () ->

        if self.password and self.message and self.contact

            deferred = $q.defer()
            messageToSend = self.message

            if self.image.data
                encryptedImage = cryptoService.encryptMessage(self.password, self.image.data)
                googleService.uploadImage(encryptedImage).then (url) ->
                    messageToSend += '\n---attachment---\n' + url
                    encryptionResult = cryptoService.encryptMessage(self.password, messageToSend)
                    twitterService.postMessage(self.contact.id, encryptionResult).then ->
                        self.justSent = true

            else

                encryptionResult = cryptoService.encryptMessage(self.password, messageToSend)
                twitterService.postMessage(self.contact.id, encryptionResult).then ->
                    self.justSent = true
                    self.password = ''
                    self.message = ''
                    self.image = ''

    $rootScope.$on 'event:contacts-loaded', (event, args) ->
        self.contacts = args.data

    @ #don't delete this - shorthand for 'return this' in coffeescript