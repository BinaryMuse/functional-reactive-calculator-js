# We start off with a `Calculator` class, which represents the state of
# a calculator; Calculators are never mutated; methods on the display
# return a new `Calculator` instance.
#
# (I'm cheating a bit here by using a class, but I'm really using it in
# a fairly functional way--consider it like Scala's case classes or
# Elixir's records.)
class Calculator
  constructor: (@value = '', @isAnswer = false, @isError = false) ->

  # Appending a value to the calculator is straightforward, unless the
  # calculator's value is currently an error (in which case we *replace*
  # the value with the new value) or an answer (in which case we
  # replace the value with the new value only if the new value is not
  # an operator).
  append: (val, isOperator) =>
    if @isError || (@isAnswer && !isOperator)
      new Calculator(val, false)
    else
      new Calculator(@toString() + val, false)

  # We use [math.js](http://mathjs.org/) to evaluate the current expression,
  # and indicate that the new value is an answer so that it will be
  # automatically replaced with any new value the user types.
  eval: =>
    return new Calculator() if @value == ''

    try
      val = math.eval(@toString())
      new Calculator(val, true)
    catch
      new Calculator('', false, true)

  clear: =>
    new Calculator()

  # Backspace can only be used on user-supplied expressions;
  # trying to backspace on an answer or error should clear the value.
  backspace: =>
    if @isAnswer || @isError
      @clear()
    else
      value = @toString()
      new Calculator(value[0...value.length - 1], false)

  toString: =>
    if @isError
      'ERROR'
    else
      @value

  # Process the given action against the current value. Note
  # that all branches result in returning a new Calculator instance.
  processAction: (action) ->
    if action.type == 'value'
      @append(action.value, action.operator)
    else if action.type == 'command'
      switch action.value
        when 'CLEAR'
          @clear()
        when 'BACKSPACE'
          @backspace()
        when 'EQUAL'
          @eval()


# Here we star the program proper. First, we'll define a set of helper
# functions for making the program work.
jQuery ->
  # Create an action object from a DOM element's `data` attributes:
  #
  # * `data-cmd` indicates that the element triggers a special command,
  #   and also indicates the actual command the element triggers
  # * `data-operator` indicates that the value is an operator
  # * `data-code` is a key code string, which is parsed by `parseCodeString`
  #
  # An action consists of four properties:
  #
  # * `type`: either 'command' or 'value', depending on if the action triggers
  #   a special command or just represents a normal button on the calculator
  # * `operator`: `true` if the value is one of the mathematical operators
  # * `value`: either the value of the action or name of the command to trigger
  # * `keys`: an array of key code objects that describe which keyboard
  #   shortcuts can be used to trigger the action
  actionFromButton = (button) ->
    button = $(button)
    {
      type:     if button.data('cmd') then 'command' else 'value'
      operator: !!button.data('operator')
      value:    button.data('cmd') || button.text()
      keys:     parseCodeString "#{button.data('code')}"
    }

  # Parse a string like "s57|50" into key code objects, where multiple
  # codes are separated by a pipe character and "s" represents pressing
  # the key with the shift key held down.
  parseCodeString = (str) ->
    str.split('|').map (str) ->
      if str[0] == 's'
        { shift: true, code: str[1...str.length] }
      else
        { shift: false, code: str }

  # Generate an action from a button's click event.
  actionFromButtonClick = (event) ->
    actionFromButton event.target

  # Generate a function that takes a key event and finds an associated
  # action in the given list of actions based on the action's key code
  # definitions. The function returns `undefined` if nothing is found.
  actionFromKeyPress = (actionList) ->
    (keyPress) ->
      code  = "#{keyPress.keyCode}"
      shift = keyPress.shiftKey

      for action in actionList
        for key in action.keys
          return action if key.code == code && key.shift == shift

  # Create a list of action objects from the current DOM for later searching.
  actionList = $('button').map (idx, button) ->
    actionFromButton(button)
  .toArray()

  # Generate a function that takes a key event and returns whether
  # or not the event's key code matches the given value.
  isKeyCode = (val) ->
    (evt) -> evt.keyCode == val

  # Returns true if no special key other than shift were pressed.
  noSpecialKeys = (evt) ->
    !(evt.altKey || evt.ctrlKey || evt.metaKey)

  # Generate streams of DOM events (button clicks and key presses).
  # Ensure that backspace doesn't navigate away by calling `preventDefault`.
  # We also filter out any key presses that include the control, alt, or meta keys.
  buttonClicks = $('button').asEventStream('click')
  keyPresses = $(document).asEventStream('keydown').filter(noSpecialKeys)
  keyPresses.filter(isKeyCode(8)).onValue('.preventDefault')

  # Now we can use the DOM events with the `actionFromButtonClick` and
  # `actionFromKeyPress` functions we created above to transform the
  # stream of DOM events into a stream of action objects.
  buttonActions = buttonClicks.map(actionFromButtonClick)
  keyActions = keyPresses.map(actionFromKeyPress(actionList)).filter('.value')
  # When we can combine the two streams into one stream of *all* actions.
  actions = buttonActions.merge(keyActions)

  # All that's left is to create a new `Calculator` object and call
  # `processAction` to generate a new value for each action in the stream.
  # For each action, we'll assign the text value to the appropriate
  # DOM element.
  actions.scan(new Calculator, '.processAction').assign $('#display'), 'val'
