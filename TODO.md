# TODOs

## Active
* New text system
    - Implement a red line through the new text system
        - Get a single word of text, no wrapping anything from a text() widget to render in a simple example
    - Font caching?
    - Layout caching?
    - Clean up the old types and text implementation

* Move input into base?

## Bugs

## Backlog
* Elements are now allocated using the general purpose heap allocator, this could probably be done using
    as `Pool_Allocator` or some other type of allocator for several benefits (simplicity, perf?).
* Review how capability flags are set in `open_element`. Currently they are additive, which
    works fine usually, but we've already seen cases where overriding it would be nice. 
* Review coordinate systems. Seems like origin is at upper left corner for fragment shader.
* `text_input` has hardcoded sizing values now, figure out how to do this in a better way.
* Simpler text helper procedure, important to think about life time there, it probably
    has to take an allocator that lives for the length of the frame, e.g. an arena allocator
    that lives on the App that gets reset for every frame. We don't wanna clone strings.
* Embossing (gradient) effects
* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.
* Adding new styles is a bit tedious and error prone.
* Hotreloading - both ui layout / styling and shaders
* Tests should probably use the outputted Command queue instad of using `find_element_by_id` to get hold of the 
    element and assert on that. The Command output from a ui pass would test the library more completely,
    and be more robust to internal changes.
* Look into a data-oriented design for the `UI_Elements` and hierarchy.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

