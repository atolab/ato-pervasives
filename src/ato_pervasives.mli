val compose : ('b -> 'c) -> ('a -> 'b) -> ('a -> 'c)

val (<.>) : ('b -> 'c) -> ('a -> 'b) -> ('a -> 'c)

val some : 'b -> ('a -> 'b) -> 'a option -> 'b

val result : ('a -> 'c) -> ('b -> 'c) -> ('a, 'b) result -> 'c
