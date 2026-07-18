# TODOs

## Active
* Look into returning errors properly, i.e. procedures that takes an allocator should return `Allocator_Error`.
* Need a better Glyph type, probably should live in base package.
* io abstraction, figure out to handle quit event, and whether that should be its own event type or a window event.
* New text system
    - Font caching?
    - Layout caching?

## Bugs

## Backlog
* Very few / if any layout sizing tests really tests border and margin.
* Don't use f32 for time, should be something like nanoseconds instead.
* Use integer / fixed point glyph metrics instead of f32 (same as FreeType, Pango) etc
* Layout margins - doesn't seem entirely right. Need to investigate and add more examples / tests for it.
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
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop and recursions.
* Adding new styles is a bit tedious and error prone.
* Hotreloading - both ui layout / styling and shaders
* Tests should probably use the outputted Command queue instad of using `find_element_by_id` to get hold of the 
    element and assert on that. The Command output from a ui pass would test the library more completely,
    and be more robust to internal changes.
* Look into a data-oriented design for the `UI_Elements` and hierarchy.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

* Consider "immediate" layout aswell as the deferred auto-layout we currently have.
    - The idea is to have an easy way to describe right then and there imperatively in the code
    the size and layout of an element, without having to go through the entire layout system.
    This can be very handy and nice to have when having to describe things that needs to be dynamic, e.g.
    put a circle at the top of the 'T' character on the button etc.
    - We make functions from the layout system available for much of this, if somewhat altered probably, example is
    "I want to right now layout 12 evenly spaced elements", that could use the same procedure to achieve that in
    immediate layout as well as it would in the deferred layout we have now.
    - Probably have to make a clear API
    - This is powerful because then a user can imperatively describe how the element / layout should look for something
        directly with just simple steps instead of trying to make this work through configuring hierarch of elements
        to achieve the same thing.

* Remove z-index integer from element, at least it should be f32, but probably just make position of element into a Vec3. 

    This will make things simpler and much more powerful because then things can be animated etc.



