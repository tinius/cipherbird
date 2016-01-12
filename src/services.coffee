ctdServices = angular.module('ctdServices', [])

#handles everything to do with the Twitter REST API
ctdServices.factory 'twitterService', ($q) ->

    twitter : null
    user : null
    contacts : null
    messages : null

    initialise : () ->
        # OAuth.initialize('BhIiiyZptQ6pQKCCaz2RaPjXweQ') old public key
        OAuth.initialize('r-DeHkzLRBjMi-olR_oWEwD3c3E')
        twitter = OAuth.create('twitter')

    twitterReady : () ->
        this.twitter

    disconnectTwitter : () ->
        OAuth.clearCache('twitter')
        this.twitter = null

    connectToTwitter : () ->
        self = this
        deferred = $q.defer()
        OAuth.popup 'twitter', (error, result) ->
            if not error
                self.twitter = result
                self.twitter.get('/1.1/account/verify_credentials.json').done (resp) ->
                    self.user = resp.screen_name
                deferred.resolve()
            else
                console.log error
        return deferred.promise

    filterContacts : (ids) ->

        count = 0

        deferred = $q.defer()
        promise = this.twitter.get(
            '/1.1/friendships/lookup.json?user_id=' + ids.join(),
        ).done (data) ->
            users = data.filter (user) ->
                return 'following' in user.connections and 'followed_by' in user.connections
            .map (user) ->
                user.screenName = user.screen_name # camel case the attribute for convenience
                user.nameLower = user.name.toLowerCase()
                user.screenNameLower = user.screenName.toLowerCase()
                return user

            deferred.resolve(users)

        return deferred.promise

    getContacts : () ->
        self = this
        deferred = $q.defer()
        if self.contactList
            deferred.resolve(self.contactList)
        else
            promise = self.twitter.get('/1.1/friends/ids.json?user_id=me&cursor=-1').done (data) ->
                self.contactList = self.filterContacts(data.ids)
                deferred.resolve(self.contactList)

        return deferred.promise

    postMessage : (recipient, message) ->
        deferred = $q.defer()
        promise = this.twitter.post('/1.1/direct_messages/new.json',
            data :
                user_id : recipient
                text : message
        ).done (data) ->
            deferred.resolve(data)
        return deferred.promise

    getMessages : (since_id = -1) ->
        self = this
        deferred = $q.defer()
        promise = self.twitter.get('/1.1/direct_messages.json?count=8&full_text=true&since_id=' + since_id).done (data) ->
            deferred.resolve(data)
        return deferred.promise

#handles cryptographic operations by using the Stanford JavaScript Crypto Library
ctdServices.factory 'cryptoService', () ->

    isEncrypted : (message) ->
        try
            salt = message.split('\n')[0]
            bits = sjcl.codec.base64.toBits(salt)
            if bits.length is 2
                return yes

        catch error

        return no

    decryptMessage : (password, message) ->

        messageLines = message.split('\n')
        salt = messageLines[0]
        iv = messageLines[1]
        ciphertext = messageLines[2]

        dh =
            v: 1,
            ts: 64,
            ks: 128,
            mode: 'ccm',
            adata: '',
            rp: '',
            iter: 1000

        dh.iv = iv
        dh.salt = salt
        dh.ct = ciphertext

        plain = sjcl.decrypt(password, JSON.stringify(dh))

        return plain

    #encrypts a message with a given password. salt and iv are sent along to allow reconstruction
    encryptMessage : (password, message) ->
        encryptionResult = JSON.parse(sjcl.encrypt(password, message))
        ciphertext = encryptionResult.ct
        salt = encryptionResult.salt
        iv = encryptionResult.iv
        return "#{salt}\n#{iv}\n#{ciphertext}"

#handles all interaction with the Google REST API
ctdServices.factory 'googleService', ($q, $http) ->

    self = this

    self.googleClientId = '594888625113-rmave0jlk2aku3ftb8caaf7mba12kc3e.apps.googleusercontent.com'
    self.googleApiKey = 'AIzaSyDRyeAZPLvaAFiQW-0Gct-9oSyLQztiJtM'
    self.scopes = ['https://www.googleapis.com/auth/drive', 'https://www.googleapis.com/auth/userinfo.email']
    self.user = null

    self.googleReady = () ->
        return self.user

    self.listFiles = () ->
       req = gapi.client.drive.files.list()
       req.execute (resp) ->
        files = resp.items

    self.getUser = () ->

        if not self.user
            accessToken = gapi.auth.getToken().access_token
            $http
                method : 'GET'
                url : 'https://www.googleapis.com/oauth2/v1/userinfo?alt=json'
                headers :
                    'Authorization' : 'Bearer ' + accessToken
            .then (resp) ->
                if resp.data.email
                    self.user = resp.data.email

        return self.user


    self.tryDownload = (url) ->
        deferred = $q.defer()
        promise = $http.get(url).then (resp) ->
            deferred.resolve(resp)

        return deferred.promise

    #asynchronously downloads an image through crossorigin.me (CORS PROXY)
    self.downloadFile = (url) ->

        deferred = $q.defer()
        promise = $http.get('https://crossorigin.me/' + url).then (resp) ->
            deferred.resolve(resp.data)
        return deferred.promise

    self.makePublic = (id, url) ->

        deferred = $q.defer()

        body =
            value : ''
            type : 'anyone'
            role : 'reader'

        req = gapi.client.drive.permissions.insert
            fileId : id
            resource : body

        req.execute (response) ->
            deferred.resolve(url)

        return deferred.promise

    self.uploadImage = (image) ->
        deferred = $q.defer()

        boundary = '-----1337'
        delimiter = '\r\n--' + boundary + '\r\n'
        closeDelimiter = '\r\n--' + boundary + '--'
        metadata = {
            mimeType : 'text/plain'
            title : 'aaa_text'
        }
        body =
            delimiter + 
            'Content-Type: application/json\r\n\r\n' +
            JSON.stringify(metadata) +
            delimiter +
            'Content-Type: text/plain\r\n' +
            'Content-Transfer-Encoding: 8bit\r\n\r\n' +
            image +
            closeDelimiter

        request = gapi.client.request
            path : '/upload/drive/v2/files'
            method : 'POST'
            params :
                uploadType : 'multipart'
            headers :
                'Content-Type' : 'multipart/mixed, boundary="' + boundary + '"'
            body : body

        request.execute (file) ->
            deferred.resolve(self.makePublic(file.id, file.webContentLink))

        return deferred.promise

    self.loadClient = () ->
        gapi.client.load('drive', 'v2', self.getUser)

    self.initialise = (authResult) ->
        #console.log "initialise call"
        if authResult and not authResult.error
            self.loadClient()
        else
            gapi.auth.authorize(
                {
                    client_id : self.googleClientId
                    scope : self.scopes
                    immediate : false
                }, self.initialise)


    self.getAccessToken = () ->
        gapi.auth.authorize(
            {
                client_id : self.googleClientId
                scope : self.scopes
                immediate : true
            }, self.initialise)

    @ #don't delete - shorthand for 'return this' in coffeescript








