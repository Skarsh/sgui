# TODOs

## Active
* (BUG) The `text` procedure doesn't respect `text_alignment_` style stack values, even if there's
    no value given to the text procedure for it. This is due to the default value being valid.
    This is probably a good opportunity to revisit how text creating procedures work as the 
    point below says.
* Rethink how to structure text creation, meaning `text` helper proc vs `element_equip_text`.
    specifically there's been a bug with text color being zeroed out so text was not visible.
    Would text just having a sensible default styling be enough?

## Bugs

## Backlog
* Scrolling feature - does this require a strictness value and its own "violations" pass?
* Remove SDL renderer, it crashes now and will never be something that we will realistically use.
* Think of using indexes / handles for referencing / storing ui elements.
* Embossing (gradient) effects
* Prune "dead" ui elements (they're still cached in the map)
* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.
* Adding new styles is a bit tedious and error prone.
* Hotreloading - both ui layout / styling and shaders

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

