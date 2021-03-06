// Generated by CoffeeScript 1.10.0
app.controller('AuthController', function($scope, $rootScope, $q, twitterService) {
  var self;
  self = this;
  twitterService.initialise();
  self.getUser = function() {
    return twitterService.user;
  };
  self.twitterReady = function() {
    return twitterService.twitterReady();
  };
  self.authClick = function() {
    if (!twitterService.twitterReady()) {
      return twitterService.connectToTwitter().then(function() {
        if (twitterService.twitterReady()) {
          twitterService.getContacts().then(function(data) {
            return $rootScope.$broadcast('event:contacts-loaded', {
              data: data
            });
          });
          return twitterService.getMessages().then(function(data) {
            return $rootScope.$broadcast('event:messages-loaded', {
              data: data
            });
          });
        }
      });
    } else {
      return twitterService.disconnectTwitter();
    }
  };
  return this;
});

app.controller('InboxController', function($scope, $rootScope, $q, twitterService, cryptoService, googleService) {
  var self;
  self = this;
  self.password = '';
  self.messages = [];
  self.currentMessage = null;
  self.displayedMessage = null;
  self.justEncrypted = false;
  self.image = 'no base64 loaded';
  self.isEncrypted = function(message) {
    return cryptoService.isEncrypted(message);
  };
  self.passwordValid = function() {
    return self.password !== null && self.password !== '';
  };
  self.checkPassword = function() {
    var e, error1;
    try {
      cryptoService.decryptMessage(self.password, self.currentMessage.text);
      return true;
    } catch (error1) {
      e = error1;
      return false;
    }
  };
  self.decryptClick = function() {
    var arr, error, error1, pw;
    self.errors = {};
    pw = self.password;
    if (self.passwordValid()) {
      try {
        self.currentMessage.decryptText = cryptoService.decryptMessage(self.password, self.currentMessage.text);
        arr = self.currentMessage.decryptText.split('\n');
        if (arr.length > 2 && arr[arr.length - 2] === '---attachment---') {
          googleService.downloadFile(arr[arr.length - 1]).then(function(image) {
            var encryptedImage;
            encryptedImage = image;
            self.currentMessage.image = cryptoService.decryptMessage(pw, encryptedImage);
            self.currentMessage.decryptText = arr.slice(0, -2).join('\n');
            return self.currentMessage.showImage = true;
          });
        }
      } catch (error1) {
        error = error1;
        console.log('You entered an incorrect password: ' + self.password);
        console.log(error);
        self.errors = {
          incorrect: true
        };
      }
      return self.password = '';
    } else {
      console.log('You did not enter a password!');
      return self.errors = {
        empty: true
      };
    }
  };
  self.hideDecrypted = function() {
    self.currentMessage.decryptText = null;
    self.currentMessage.image = null;
    return self.currentMessage.showImage = false;
  };
  self.selectMessage = function(message) {
    return self.currentMessage = message;
  };
  self.loadMessages = function() {
    if (self.messages.length === 0) {
      return twitterService.getMessages().then(function(data) {
        console.log("getting da msgs");
        return self.messages = data.filter(function(msg) {
          return self.isEncrypted(msg.text);
        });
      });
    } else {
      return twitterService.getMessages(self.messages[0].id_str).then(function(data) {
        return self.messages = data.filter(function(msg) {
          return self.isEncrypted(msg.text);
        }).concat(self.messages).slice(0, 9);
      });
    }
  };
  self.loadContacts = function() {
    return twitterService.getContacts().then(function(data) {
      return $scope.contactList = data;
    });
  };
  self.previewMessage = function(message) {
    if (message.length > 20) {
      return message.substring(0, 20) + '...';
    } else {
      return message;
    }
  };
  $rootScope.$on('event:messages-loaded', function(event, args) {
    return self.messages = args.data.filter(function(msg) {
      return self.isEncrypted(msg.text);
    });
  });
  return this;
});

app.controller('ComposeController', function($scope, $rootScope, $q, twitterService, googleService, cryptoService) {
  var self;
  self = this;
  self.password = '';
  self.contacts = '';
  self.message = '';
  self.justSent = false;
  self.image = {};
  self.driveAuth = function() {
    return googleService.getAccessToken();
  };
  self.getGoogleUser = function() {
    return googleService.getUser();
  };
  self.googleReady = function() {
    return googleService.googleReady();
  };
  self.makeFilter = function(query) {
    var queryLower;
    queryLower = angular.lowercase(query);
    if (queryLower.substring(0, 1) === '@') {
      queryLower = queryLower.substring(1);
      return function(user) {
        return user.screenNameLower.indexOf(queryLower) === 0;
      };
    }
    return function(user) {
      return user.nameLower.indexOf(queryLower) === 0 || user.screenNameLower.indexOf(queryLower) === 0;
    };
  };
  self.searchContacts = function(query) {
    if (query) {
      return self.contacts.filter(self.makeFilter(query));
    } else {
      return self.contacts;
    }
  };
  self.composeAnother = function() {
    return self.justSent = false;
  };
  self.sendMessage = function() {
    var deferred, encryptedImage, encryptionResult, messageToSend;
    if (self.password && self.message && self.contact) {
      deferred = $q.defer();
      messageToSend = self.message;
      if (self.image.data) {
        encryptedImage = cryptoService.encryptMessage(self.password, self.image.data);
        return googleService.uploadImage(encryptedImage).then(function(url) {
          var encryptionResult;
          messageToSend += '\n---attachment---\n' + url;
          encryptionResult = cryptoService.encryptMessage(self.password, messageToSend);
          return twitterService.postMessage(self.contact.id, encryptionResult).then(function() {
            return self.justSent = true;
          });
        });
      } else {
        encryptionResult = cryptoService.encryptMessage(self.password, messageToSend);
        return twitterService.postMessage(self.contact.id, encryptionResult).then(function() {
          self.justSent = true;
          self.password = '';
          self.message = '';
          return self.image = '';
        });
      }
    }
  };
  $rootScope.$on('event:contacts-loaded', function(event, args) {
    return self.contacts = args.data;
  });
  return this;
});
