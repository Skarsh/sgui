# TODOs

## Active

## Bugs
* blinking caret in `text_input` widget resizes the text element for some reason
* Using `element_equip_text` in the `text_input` helper proc makes the text invisible compared to just using the `text` proc

## Backlog
* Helper procedures should use `begin_container` helpers instead of `open_element` and `close_element`
* Spacer helper, this will require to think about null ids though so its more complicated than
    it might seem like.
* Simpler text helper procedure, important to think about life time there, it probably
    has to take an allocator that lives for the length of the frame, e.g. an arena allocator
    that lives on the App that gets reset for every frame. We don't wanna clone strings.
* Rethink how to structure text creation, meaning `text` helper proc vs `element_equip_text`.
    specifically there's been a bug with text color being zeroed out so text was not visible.
    Would text just having a sensible default styling be enough?
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

