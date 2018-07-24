exception Terminate

val spawn :
  ?queue_len:int ->
  ?timeout:('a -> 'a) Actor.Actor.timeout_info option ->
  ?on_terminate:('a -> 'a) option ->
  'a -> ('a -> 'b) -> ('b -> 'a) -> 
  (('a -> 'a) -> unit Lwt.t) * unit Lwt.t

val terminate : 'a -> 'b

val pure : 'a -> 'b -> 'b * 'a
val readonly : ('a -> 'b) -> 'a -> 'a * 'b

val ( @%> ) : ('a -> 'b * 'c) -> ('c -> 'd) -> 'a -> 'b
val ( %@> ) : ('a -> 'b * 'c) -> ('b -> 'd) -> 'a -> 'c
