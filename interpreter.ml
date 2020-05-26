

(* things that goes on a stack *)
type stackVal = 
    I of int 
  | S of string 
  | N of string
  | B of bool 
  | U
  | E
  | Clo of (stackVal * env * command list )


  and

(* well formed instructions *)
command = PushI of stackVal 
             | PushS of stackVal 
             | PushN of stackVal 
             | PushB of stackVal
             | Push of stackVal
             | Add | Sub | Mul | Div | Rem | Neg
             | Concat
             | And | Or | Not
             | Equal | LessThan
             | If
             | Pop
             | Swap
             | Begin | End (* This solution uses seperate commands for Begin ... End *)
             | Fun of (stackVal * stackVal * command list) (* handle blocks together *)
             
             | Bind
             | Call
             | Return
             | Quit
             

and


env = (string * stackVal) list list

let insert (s:string)  (sv : stackVal) (env: env) : env = 
    match env with
      | frame :: frames  -> ((s, sv) :: frame) :: frames
      | []               -> [[(s, sv)]]

let rec fetch (name :string)  (env: env) : stackVal option = 
    match env with
      | ((name' , v) :: frame) :: frames  -> if name = name' then Some v else fetch name (frame :: frames)
      | []                     :: frames  -> fetch name frames
      | []                                -> None
      
let empEnv = [[]]
let pushEnv  (env: env) : env  = [] :: env

let popEnv (env: env) : env  = 
  match env with
    | [] -> empEnv
    | _ :: rest ->  rest


let combEnv (env1: env) (env2: env) : env =
  match env1 with 
    | [] -> empEnv
    | x :: rest ->  (match env2 with
                    | [] -> empEnv
                    | y :: rest2 -> [x @ y ] @ rest
)

 
 let empStack = [[]]
 let pushStack  (stack: stackVal list list) : stackVal list list  = [] :: stack

let popStack (stack: stackVal list list) : stackVal list list  = 
  match stack with
    | [] -> empStack
    | _ :: rest ->  rest


let insertStack  (sv: stackVal) (stack: stackVal list list) : stackVal list list  = 
  match stack with
    | [] -> [[sv]]
    | h :: r  -> (sv :: h) :: r


let rec run (commands : command list) (stack: stackVal list list) (env: env) : stackVal list = 
  (* if stackVal is a variable what  does it resolve to in the current environment *)
  let res (sv : stackVal) : stackVal = 
    match sv with 
      | N n -> (match fetch n env with  
                  | Some n' -> n' 
                  | None -> N n)
      | sv -> sv
  in let bad rest : stackVal list = (run rest (insertStack E stack) env) (* every command fails in the same way *)
  in match (commands , stack)  with
  | (PushI (I i) :: rest, _                      ) -> run rest (insertStack (I i) stack) env
  
  | (PushS (S s) :: rest, _                      ) -> run rest (insertStack (S s)  stack) env
  
  | (PushN (N n) :: rest, _                      ) -> run rest (insertStack (N n) stack) env
  
  | (PushB (B b) :: rest, _                      ) -> run rest (insertStack (B b) stack) env
  
  | (Push U      :: rest, _                      ) -> run rest (insertStack U stack) env
  | (Push E      :: rest, _                      ) -> run rest (insertStack E stack) env
  
  | (Add         :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (I i, I j) -> run rest ((I (i+j) :: s' ) :: frames) env 
                                                        | _ -> bad rest)

  | (Sub         :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (I i, I j) -> run rest ((I (i-j) :: s' ) :: frames) env 
                                                        | _ -> bad rest)
  
  | (Mul         :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (I i, I j) -> run rest ((I (i*j) :: s' ) :: frames) env 
                                                        | _ -> bad rest)
  
  | (Div         :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (I i, I 0) -> bad rest
                                                        | (I i, I j) -> run rest ((I (i/j) :: s' ) :: frames) env 
                                                        | _ -> bad rest)

  | (Rem         :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (I i, I 0) -> bad rest
                                                        | (I i, I j) -> run rest ((I (i mod j) :: s' ) :: frames)  env 
                                                        | _ -> bad rest)
  
  | (Neg         :: rest, (x ::s')     :: frames) -> (match (res x) with 
                                                        | (I i) -> run rest ((I (-i) :: s' ) :: frames) env 
                                                        | _ -> bad rest)

  | (Concat      :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (S i, S j) -> run rest ((S (i ^ j) :: s') :: frames) env 
                                                        | _ -> bad rest)
  
  | (And         :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (B i, B j) -> run rest ((B (i && j) :: s') :: frames) env 
                                                        | _ -> bad rest)
  
  | (Or          :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (B i, B j) -> run rest ((B (i || j) :: s') :: frames) env 
                                                        | _ -> bad rest)
  
  | (Not         :: rest, (x ::s')     :: frames) -> (match (res x) with 
                                                        | (B i) -> run rest ((B (not i) :: s') :: frames) env 
                                                        | _ -> bad rest)

  | (Equal       :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (I i, I j) -> run rest ((B (i = j) :: s') :: frames) env 
                                                        | _ -> bad rest)
  | (LessThan    :: rest, (x ::y ::s') :: frames) -> (match (res x, res y) with 
                                                        | (I i, I j) -> run rest ((B (i < j) :: s') :: frames) env 
                                                        | _ -> bad rest)
                                        
  | (If          :: rest,(x::y::z::s') :: frames) -> (match res z with 
                                                        | B true -> run rest ((y :: s'):: frames) env 
                                                        | B false -> run rest ((x :: s'):: frames) env 
                                                        | _ -> bad rest)

  | (Pop         :: rest, (_ :: s')    :: frames) -> run rest (s' :: frames) env
  
  | (Swap        :: rest,( x ::y ::s') :: frames) -> run rest (( y ::x ::s') :: frames) env
  
  | (Bind        :: rest, ( N n::x::s'):: frames) -> (match res x with
                                                        | E   -> bad rest 
                                                        | N _ -> bad rest (* unbound var *)
                                                        | v -> run rest ((U :: s'):: frames) (insert n v env) )

  | (Begin       :: rest, frames                ) -> run rest ([] :: frames) (pushEnv env)
  | (End         :: rest, ((top :: _) :: frames)) -> run rest (insertStack top frames) (popEnv env)
 
  | (Quit        :: _   , s :: _                ) -> s
  | ([]                 , s :: _                ) -> s
  | (Fun (N x,y,cm):: rest, s'                    ) -> run rest ((insertStack U s')) (insert x (Clo (y,env,cm)) env)
  
  | (Call        :: rest, (E ::  y ::s') :: frames) -> bad rest
  | (Call        :: rest, (x :: y ::s') :: frames) -> (match (res y, res x) with
                                                      | (Clo (N a,b,c),v) -> (let (top :: _) = run c (pushStack ((s')::frames)) ((insert a v b)@env)
                                                                            in run rest ((top::s')::frames) env)
                                                      | _ -> bad rest
                                                    )

                                                 (*(let (top :: _) = run c (pushStack ((s')::frames)) ((insert a v b)@env)
                                                    in run rest ((top::s')::frames) env





                                                    )(*(match (res y, res x) with
                                                      | (Clo (N a,b,c),v) -> run (c @ rest) (pushStack ((s')::frames)) ((insert a v b)@env)
                                                      | _ -> bad rest
                                                    )*)
                                                  *)
                                                        

  

   | (Return :: rest, ((x::s'):: frames)    ) -> [res x]
  
  (*| (FunEnd      :: rest, (_):: frames            ) -> run rest frames (popEnv env) *)
 

  
  | (_           :: rest, _                     ) -> bad rest
(*
let rec funrun (restcmds: command list) (cmds: command list) (stack : stackVal list list) (env:env) : ( stackVal list *  command list )=
*)
(* remember to test! *)
let e2 = run [PushI (I 1); PushI (I 1); Add] [] empEnv
let e3 = run [PushN (N "x"); PushI (I 1); Add] [] (insert "x" (I 7) empEnv)
let e4 = run [PushN (N "x"); PushI (I 1); Add] [] empEnv
let e5 = run [PushI (I 500); PushI (I 2); Mul; PushI (I 2);  Div] [] empEnv
let e6 = run [PushS (S "world!"); PushS (S "hello "); Concat] [] empEnv
let e7 = run [PushI (I 7); PushI (I 8); LessThan] [] empEnv
let e8 = run [PushI (I 7); PushI (I 7); Equal] [] empEnv
let e9 = run [PushI (I 13); PushN (N "a"); Bind; PushI (I 3); PushN (N "name1"); Bind;  PushN (N "a"); PushN (N "name1"); Add] [] empEnv
let e10 = run [PushB (B true); PushS (S "o"); PushS (S "j"); If] [] empEnv
(* ... *)

let e11 =  run [PushS (S "str1"); PushN (N "str1"); PushI (N "str1"); PushI (I 1); Pop;
   PushI (I 3); Pop; Begin; PushI (I 5); End; Pop; Begin; PushI (I 17);
   PushN (N "c"); Bind; Begin; PushI (I 3); PushN (N "a"); Bind;
   PushN (N "a"); PushN (N "c"); Add; End; Begin; PushS (S "ronaldo");
   PushN (N "b"); Bind; End; End; PushI (I 30); PushI (I 40); Quit] [] empEnv

(* writing *)
let to_string (s : stackVal) : string = 
  match s with
  | I i -> string_of_int i 
  | S s  -> s
  | N n -> n
  | B b -> "<" ^ string_of_bool b ^ ">"
  | U   -> "<unit>"
  | E   -> "<error>"
  | Clo (N x,y,z) -> "closer " ^ x
  


(* parser combinators over exploded strings *)
let explode (s:string) : char list =
  let rec expl i l =
    if i < 0 
    then l 
    else expl (i - 1) (String.get s i :: l)
  in expl (String.length s - 1) []

let implode (cl:char list) : string = 
  String.concat "" (List.map (String.make 1) cl)

 
let is_alpha (c:char): bool = 
  (Char.code 'a' <= Char.code c && Char.code c <= Char.code 'z')
  || (Char.code 'A' <= Char.code c && Char.code c <= Char.code 'Z')

let is_digit (c:char): bool = 
 Char.code '0' <= Char.code c && Char.code c <= Char.code '9'

let rec take_while' (p: 'a -> bool) (es : 'a list) : ('a list) * ('a list) = 
  match es with
  | []      -> ([],[])
  | x :: xs -> if p x then let (chars, rest) = take_while' p xs in  (x :: chars, rest) else ([], x :: xs)

let take_while (p:char -> bool) (s:string) : string * string = 
  let (echars, erest) = take_while' p (explode s) 
  in (implode echars, implode erest)


let parse_int (s : string) : int option = 
    match int_of_string s with    
    | n -> Some n
    | exception _ -> None

let parse_string (s : string) : string option = 
    if String.length s > 1 && String.get s 0 = '"' && String.get s (String.length s - 1) = '"'
    then  Some (String.sub s 1 (String.length s - 2)) (* this is less restrictive then the spec *)
    else None


let parse_name (s : string) : string option = 
    if String.length s > 0 && ( let c = (String.get s 0) in is_alpha c ||  c = '_')
    then  Some s (* this is less restrictive then the spec *)
    else None
    
    
    
let parse_constant (s:string) : stackVal = 
    let s' = String.trim s in
    match s' with
    | "<true>"  -> B true
    | "<false>" -> B false
    | "<unit>"  -> U
    | _ -> match parse_int s' with
           | Some i -> I i
           | None -> match parse_string s' with
                     | Some s -> S s
                     | None -> match parse_name s' with
                               | Some s -> N s
                               | None -> E



let parse_single_command (s:string) : command = 
    match take_while is_alpha (String.trim s) with
    | ("PushI"   , p) -> PushI (parse_constant p)
    | ("PushS"   , p) -> PushS (parse_constant p)
    | ("PushN"   , p) -> PushN (parse_constant p)
    | ("PushB"   , p) -> PushB (parse_constant p)
    | ("Push"    , p) -> Push (parse_constant p)
    | ("Add"     , _) -> Add
    | ("Sub"     , _) -> Sub
    | ("Mul"     , _) -> Mul
    | ("Div"     , _) -> Div
    | ("Rem"     , _) -> Rem
    | ("Neg"     , _) -> Neg
    | ("Pop"     , _) -> Pop
    | ("Swap"    , _) -> Swap
    | ("Concat"  , _) -> Concat
    | ("And"     , _) -> And
    | ("Or"      , _) -> Or
    | ("Not"     , _) -> Not
    | ("LessThan", _) -> LessThan
    | ("Equal"   , _) -> Equal
    | ("If"      , _) -> If
    | ("Begin"   , _) -> Begin
    | ("End"     , _) -> End
    | ("Bind"    , _) -> Bind
    | ("Quit"    , _) -> Quit
    | ("Call"    , _) -> Call
    | ("Return"  , _) -> Return
    (* any unknown commands will result in an exception *)

let rec parse_until_end (ls :string list) :  (command list) * (string list)  =  
    match ls with 
    | []              -> ([], [])
    
    | "FunEnd" ::     tl ->  ([], tl)
    (*
    | "Fun" ::     tl ->  let (cls, rest) = parse_until_end tl
                            in let block = Block cls
                            in let (cls', rest') = parse_until_end rest
                            in (block :: cls', rest')
    *)
    | h ::     tl         -> (let temp = take_while is_alpha (String.trim h) in
                              match temp with
                              | ("Fun",temp2) -> (let (cls, rest) = parse_until_end tl
                                              in let info = String.split_on_char ' ' temp2
                                              in let block = Fun (N (List.nth info 1),N (List.nth info 2), cls)
                                              in let (cls', rest') = parse_until_end rest
                                              in (block :: cls', rest'))
                              | _ -> (let com = parse_single_command h
                             in let (cls, rest) = parse_until_end tl
                             in (com :: cls, rest)))


let parse_commands (ls :string list) : command list =
  let (coms, _) = parse_until_end ls 
  in coms
(*
let re parse_until_end (ls: string list) : 
 file IO *)
let pe25 = parse_commands ["PushB <true>";"Fun test x";"PushI 8";"PushI 9";"FunEnd";"PushI 10";"Begin";"PushI 11";"End";"PushI 12";"Quit"]

(* from lab 3 *)
let rec read_lines (ch : in_channel) : string list =
  match input_line ch with 
    | str                    -> str :: read_lines ch
    | exception  End_of_file -> [] (* input_line throws an exception at the end of the file *)
    
    
(* from lab 3 *)
let rec write_lines (ch) (ls : string list ) : unit =
  match ls with
    | []      -> ()
    | x :: xs -> let _ = Printf.fprintf ch "%s\n" x in write_lines ch xs
    


(* run the interperter on the commands in inputFile and write the resulting stack in outputFile *)
let interpreter (inputFile : string) (outputFile : string) : unit =
  let ic = open_in inputFile in
  let lines_in = List.map String.trim (read_lines ic) in
  let _ = close_in ic in
  
  let commands = parse_commands lines_in in
  let stack = run commands [[]] empEnv in
  let lines_out = List.map to_string stack in
  
  let oc = open_out outputFile in
  let _ = write_lines oc lines_out in
  let _ = close_out oc in ()