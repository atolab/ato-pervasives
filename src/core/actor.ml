open Lwt.Infix
module Actor = struct
    
    
    module EventStream = Event_stream.EventStream.Make(Stream_lwt.Stream)
    module ActorId = Id.Make(Int64)
    
    type 'msg timeout_info = (float * (float -> 'msg))
    
    type ('mbox, 'msg) actor_message = 
      | ActorMessage of ('mbox option  * 'msg) 
      | Timeout of 'msg timeout_info  
      | Terminate 
      | EmptyMessage

    type 'msg actor_mailbox = ActorMailbox of 
      { aid : ActorId.t
      ; inbox : ('msg actor_mailbox, 'msg) actor_message EventStream.Source.s
      ; outbox:   ('msg actor_mailbox, 'msg) actor_message EventStream.Sink.s }

    type  'msg t = 
      { mailbox : 'msg actor_mailbox  
      ; timeout : 'msg timeout_info option              
      ; run_loop : unit Lwt.t
      ; completer : unit Lwt.u 
      ; aid : ActorId.t} 
    
    type ('msg, 's) reaction = 'msg t -> 's option -> 'msg actor_mailbox  option -> 'msg -> ('msg t * 's option * bool) Lwt.t 
    

    let addr actor = actor.mailbox

    let spawn ?(queue_len=256) ?(state=None) ?(timeout=None) ?(on_terminate=None) (handler : ('msg, 's) reaction) =                         
      let (inbox, outbox) = EventStream.create queue_len in
      let aid = ActorId.next_id () in
      let mailbox = ActorMailbox { aid ; inbox ; outbox } in 
      let (run_loop, completer) = Lwt.task () in     
      let self = 
        { mailbox
        ; timeout
        ; run_loop
        ; completer
        ; aid = ActorId.next_id () } in            
      let rec loop handler (self, state, continue) = 
        match continue with 
        | true -> 
          let ps = ((EventStream.Source.get inbox) >|= (function  Some msg ->msg | None -> EmptyMessage)) ::
          (match self.timeout with 
            | Some (period, make_timeout) ->  [ Lwt_unix.sleep period >|= fun () -> Timeout (period, make_timeout) ]        
            | None -> []) 
          in (match%lwt Lwt.pick ps with 
            | ActorMessage (from, msg) -> 
              (* let%lwt _ = Lwt_io.printf "Received Actor Message" in *)
              (handler self state from msg) >>= (loop handler)
            | Timeout (period, make_timeout) -> 
              (* let%lwt _ = Lwt_io.printf "Received Actor Timeout" in *)
              (handler self state None (make_timeout period)) >>= (loop handler)
            | EmptyMessage ->  
              (* let%lwt _ = Lwt_io.printf "Received Actor EmptyMessage" in *)
              loop handler (self, state, true)
            | Terminate -> 
              (* let%lwt _ = Lwt_io.printf "Received Actor Terminate" in *)
              match self.mailbox with 
              | ActorMailbox { aid=_ ; inbox=_ ; outbox=outbox} -> 
                  EventStream.Sink.close outbox
                  ; let r = Common.Option.bind on_terminate (fun make_terminate_message -> Some (handler self state None (make_terminate_message ())))  in
                  Common.Option.get_or_default r (Lwt.return (self, state, true))
                  >>= (fun  _ ->  
                        Lwt.wakeup self.completer () 
                        ; Lwt.return_unit))                                                   
        | false -> 
          Lwt.wakeup self.completer () 
          ; Lwt.return_unit
      in            
      Lwt.async (fun () ->  loop handler (self, state, true)) 
      ; (mailbox, run_loop) 

    (* let receive ?(queue_len=256) ?(state=None) ?(timeout=None) handler =  *)


    let set_timeout actor  timeout_info = {actor with timeout = timeout_info }
    let get_timeout actor = actor.timeout

    let send  (ActorMailbox {aid=_ ; inbox=_; outbox=outbox} ) from msg = EventStream.Sink.push (ActorMessage (from, msg)) outbox
    

    let maybe_send dest from msg = match dest with       
      | Some actor -> send actor from msg 
      | None -> Lwt.return_unit
  
    
    
    let compare (ActorMailbox {aid=id_a; inbox=_; outbox=_})  (ActorMailbox {aid=id_b; inbox=_; outbox=_}) = ActorId.compare id_a id_b
    


 
    let close (ActorMailbox {aid=_ ; inbox=_; outbox=outbox}) =   EventStream.Sink.push Terminate outbox


    let terminate actor state () = Lwt.return (actor, state, false) 
    let continue actor state () = Lwt.return (actor, state, true) 

     module Infix = struct 
      let (<!>) dest  (from, msg) = send dest from msg
      let (<?!>) dest (from,message) = maybe_send dest from message 
      
      module Eq = struct 
        let (=) a b = compare a b = 0
      end
    end 
    
  end

  