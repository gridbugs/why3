
let rec trim cin =
  match input_line cin with
  | exception End_of_file -> ()
  | s ->
      print_endline (String.trim s);
      trim cin

let () = trim (open_in Sys.argv.(1))
