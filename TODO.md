# TODOs

## Active
* To-Do List
    * Spacer segfault, this seems to happen when add a new row and we have 2 (or probably more), spacers
        with an empty / null id. The segfault goes away if I give the second spacer element in the task list
        an unique id.  The issue seems to be that the newly added second spacer in the new row has null pointer children.
        When starting with three tasks in the `to_do_list` example, then one can remove one and add it back without this
        segfault triggering. It only happens when there is a task added.
        Make reduction that repros this.
    * Need spacer helper here
    * Need checkbox helper with checkmarking
* Styling ergonomy - Need to improve this before there's too much code to change.

## Bugs
* Text input had no height before adding the Add button in the `to_do_list` example.
    Need to try to make a repro of this in a reduced example.

## Backlog
* Aligning text elements on different rows, where on the row the text element has a spacer
    on the left and the right, is not really possible due to space being distributed evenly
    between the spacers. A solution could be something along the lines of being able
    to give weight to the spacer, e.g. give all space to this spacer until it can't grow anymore, or something.
* Helper procedures should use `begin_container` helpers instead of `open_element` and `close_element`
* Simpler text helper procedure, important to think about life time there, it probably
    has to take an allocator that lives for the length of the frame, e.g. an arena allocator
    that lives on the App that gets reset for every frame. We don't wanna clone strings.
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

