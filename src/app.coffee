#Starting point of the app. Loads it as 'cryptoTwitterDms' and injects dependencies (my services as well as other required libraries)
app = angular.module('cipherbird', ['ctdServices', 'ngAria', 'ngMaterial', 'ngMessages', 'angularValidator'])
