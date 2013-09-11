var Calculator,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

Calculator = (function() {
  function Calculator(value, isAnswer, isError) {
    this.value = value != null ? value : '';
    this.isAnswer = isAnswer != null ? isAnswer : false;
    this.isError = isError != null ? isError : false;
    this.toString = __bind(this.toString, this);
    this.backspace = __bind(this.backspace, this);
    this.clear = __bind(this.clear, this);
    this["eval"] = __bind(this["eval"], this);
    this.append = __bind(this.append, this);
  }

  Calculator.prototype.append = function(val, isOperator) {
    if (this.isError || (this.isAnswer && !isOperator)) {
      return new Calculator(val, false);
    } else {
      return new Calculator(this.toString() + val, false);
    }
  };

  Calculator.prototype["eval"] = function() {
    var val;
    if (this.value === '') {
      return new Calculator();
    }
    try {
      val = math["eval"](this.toString());
      return new Calculator(val, true);
    } catch (_error) {
      return new Calculator('', false, true);
    }
  };

  Calculator.prototype.clear = function() {
    return new Calculator();
  };

  Calculator.prototype.backspace = function() {
    var value;
    if (this.isAnswer || this.isError) {
      return this.clear();
    } else {
      value = this.toString();
      return new Calculator(value.slice(0, value.length - 1), false);
    }
  };

  Calculator.prototype.toString = function() {
    if (this.isError) {
      return 'ERROR';
    } else {
      return this.value;
    }
  };

  Calculator.prototype.processAction = function(action) {
    if (action.type === 'value') {
      return this.append(action.value, action.operator);
    } else if (action.type === 'command') {
      switch (action.value) {
        case 'CLEAR':
          return this.clear();
        case 'BACKSPACE':
          return this.backspace();
        case 'EQUAL':
          return this["eval"]();
      }
    }
  };

  return Calculator;

})();

jQuery(function() {
  var actionFromButton, actionFromButtonClick, actionFromKeyPress, actionList, actions, buttonActions, buttonClicks, isKeyCode, keyActions, keyPresses, noSpecialKeys, parseCodeString;
  actionFromButton = function(button) {
    button = $(button);
    return {
      type: button.data('cmd') ? 'command' : 'value',
      operator: !!button.data('operator'),
      value: button.data('cmd') || button.text(),
      keys: parseCodeString("" + (button.data('code')))
    };
  };
  parseCodeString = function(str) {
    return str.split('|').map(function(str) {
      if (str[0] === 's') {
        return {
          shift: true,
          code: str.slice(1, str.length)
        };
      } else {
        return {
          shift: false,
          code: str
        };
      }
    });
  };
  actionFromButtonClick = function(event) {
    return actionFromButton(event.target);
  };
  actionFromKeyPress = function(actionList) {
    return function(keyPress) {
      var action, code, key, shift, _i, _j, _len, _len1, _ref;
      code = "" + keyPress.keyCode;
      shift = keyPress.shiftKey;
      for (_i = 0, _len = actionList.length; _i < _len; _i++) {
        action = actionList[_i];
        _ref = action.keys;
        for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
          key = _ref[_j];
          if (key.code === code && key.shift === shift) {
            return action;
          }
        }
      }
    };
  };
  actionList = $('button').map(function(idx, button) {
    return actionFromButton(button);
  }).toArray();
  isKeyCode = function(val) {
    return function(evt) {
      return evt.keyCode === val;
    };
  };
  noSpecialKeys = function(evt) {
    return !(evt.altKey || evt.ctrlKey || evt.metaKey);
  };
  buttonClicks = $('button').asEventStream('click');
  keyPresses = $(document).asEventStream('keydown').filter(noSpecialKeys);
  keyPresses.filter(isKeyCode(8)).onValue('.preventDefault');
  buttonActions = buttonClicks.map(actionFromButtonClick);
  keyActions = keyPresses.map(actionFromKeyPress(actionList)).filter('.value');
  actions = buttonActions.merge(keyActions);
  return actions.scan(new Calculator, '.processAction').assign($('#display'), 'val');
});
