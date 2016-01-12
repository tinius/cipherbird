app.filter 'dateMakerFilter', () ->
    return (input) ->
        return new Date(input)