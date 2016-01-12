app.directive 'ngFileModel', () ->
	scope : 
		'ngFileModel' : '='
	link : (scope, el, attrs) ->
		el.bind 'change', (changeEvent) ->
			reader = new FileReader()
			reader.onload = (loadEvent) ->
				scope.$apply () ->
					scope.ngFileModel = 
						name : changeEvent.target.files[0].name
						data : loadEvent.target.result

			console.debug JSON.stringify(scope.ngFileModel)

			reader.readAsDataURL(changeEvent.target.files[0])


app.directive 'pwcheck', () ->
	restrict : 'A'
	require : 'ngModel'
	link : (scope, el, attrs, ngModel) ->
		ngModel.$validators.pwcheck = (modelValue) ->
			scope.inboxCtrl.checkPassword()

