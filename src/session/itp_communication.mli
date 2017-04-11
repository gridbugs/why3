type prover = string
type transformation = string
type strategy = string

type node_ID = int
val root_node : node_ID

(* --------------------------- types to be expanded if needed --------------------------------- *)

(* Global information known when server process has started and that can be
   shared with the IDE through communication *)
type global_information =
    {
     provers         : prover list;
     transformations : transformation list;
     strategies      : strategy list;
     commands        : string list
     (* hidden_provers       : string list; *)
     (* session_time_limit   : int; *)
     (* session_mem_limit    : int; *)
     (* session_nb_processes : int; *)
     (* session_cntexample   : bool; *)
     (* main_dir             : string *)
    }

type message_notification =
  | Proof_error           of node_ID * string
  | Transf_error          of node_ID * string
  | Strat_error           of node_ID * string
  | Replay_Info           of string
  | Query_Info            of node_ID * string
  | Query_Error           of node_ID * string
  | Help                  of string
  (* General information *)
  | Information           of string
  (* Number               of task scheduled, running, etc *)
  | Task_Monitor          of int * int * int
  (* A file was read or reloaded and now contains a parsing or typing error *)
  | Parse_Or_Type_Error   of string
  (* An error happened that could not be identified in server *)
  | Error                 of string
  | Open_File_Error       of string

type node_type =
  | NRoot
  | NFile
  | NTheory
  | NTransformation
  | NGoal
  | NProofAttempt

type update_info =
  | Proved of bool
  | Proof_status_change of
      Controller_itp.proof_attempt_status
      * bool   (* obsolete or not *)
      * Call_provers.resource_limit

type notification =
  | New_node     of node_ID * node_ID * node_type * string * bool
  (* Notification of creation of new_node:
     New_node (new_node, parent_node, node_type, name, detached). *)
  | Node_change  of node_ID * update_info
  (* inform that the data of the given node changed *)
  | Remove       of node_ID
  (* the given node was removed *)
  | Next_Unproven_Node_Id of node_ID * node_ID
  (* Next_Unproven_Node_Id (asked_id, next_unproved_id). Returns a node and the
     next unproven node from this node *)
  | Initialized  of global_information
  (* initial global data *)
  | Saved
  (* the session was saved on disk *)
  | Message      of message_notification
  (* an informative message, can be an error message *)
  | Dead         of string
  (* server exited *)
  | Task         of node_ID * string
  (* the node_ID's task *)
  | File_contents of string * string
  (* File_contents (name, contents) *)

type ide_request =
  | Command_req             of node_ID * string
  | Prove_req               of node_ID * prover * Call_provers.resource_limit
  | Transform_req           of node_ID * transformation * string list
  | Strategy_req            of node_ID * strategy
  | Open_session_req        of string
  | Add_file_req            of string
  | Set_max_tasks_req       of int
  | Get_file_contents       of string
  | Get_task                of node_ID
  | Remove_subtree          of node_ID
  | Copy_paste              of node_ID * node_ID
  | Copy_detached           of node_ID
  | Get_first_unproven_node of node_ID
  | Get_Session_Tree_req
  | Save_req
  | Reload_req
  | Replay_req
  | Exit_req
