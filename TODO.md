# TODOs

## Active

## Bugs

## Backlog
* Review how capability flags are set in `open_element`. Currently they are additive, which
    works fine usually, but we've already seen cases where overriding it would be nice. 
* Review coordinate systems. Seems like origin is at upper left corner for fragment shader.
* Make it possible to pass in memory chunks to the app, so that the usage code
    can control how much memory is used for the app and to which part.
* Styling ergonomy - Need to improve this before there's too much code to change.
* `text_input` has hardcoded sizing values now, figure out how to do this in a better way.
* Text sizing is a bit complicated now, with different modes. Text should probably just work with
    .Fit `Size_Kind`. This might cause some other issues, so holding it off for now.
* Helper procedures should use `begin_container` helpers instead of `open_element` and `close_element`
* Simpler text helper procedure, important to think about life time there, it probably
    has to take an allocator that lives for the length of the frame, e.g. an arena allocator
    that lives on the App that gets reset for every frame. We don't wanna clone strings.
* Remove SDL renderer, it crashes now and will never be something that we will realistically use.
* Embossing (gradient) effects
* Prune "dead" ui elements (they're still cached in the map)
* Upper Bound Limit Recursion
    We are recursively traversing the Element hierarchy with no bounds. We should try to ensure that we always have an upper bounds on loop 
    and recursions.
* Adding new styles is a bit tedious and error prone.
* Hotreloading - both ui layout / styling and shaders
* Tests should probably use the outputted Command queue instad of using `find_element_by_id` to get hold of the 
    element and assert on that. The Command output from a ui pass would test the library more completely,
    and be more robust to internal changes.

* Property testing
    When the API has somewhat stabilized we should add property testing, e.g. generate Layout scenarios and assert properties
    that we know are supposed to be true holds. Examples are parent elements should always be bigger than their children etc.

