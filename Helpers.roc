module [run, decodeJSON, reply, sendMessage, Payload]

import pf.Task exposing [Task]
import pf.Stdin
import pf.Stdout
import pf.Stderr
import json.Json

jsonCoder = Json.utf8With { fieldNameMapping: SnakeCase, skipMissingProperties: Bool.true }

encodeJSON : a -> Str where a implements Encoding
encodeJSON = \a ->
    when Str.fromUtf8 (Encode.toBytes a jsonCoder) is
        Ok o -> o
        Err err ->
            errStr = Inspect.toStr err
            crash "encodeJSON: $(errStr)"

decodeJSON : Str -> a where a implements Decoding
decodeJSON = \str ->
    when Decode.fromBytes (Str.toUtf8 str) jsonCoder is
        Ok p -> p
        Err err ->
            errStr = Inspect.toStr err
            crash "decodeJSON: $(errStr)"

NodeState a : [State { nodeId : Str, msgId : U64 }a]

reply : NodeState a, { src : Str, body : { msgId : U64 }* }*, { msgId : U64, inReplyTo : U64 }* -> Task (NodeState a) _
reply = \state, msg, body ->
    sendMessage state msg.src { body & inReplyTo: msg.body.msgId }

sendMessage : NodeState a, Str, { msgId : U64 }* -> Task (NodeState a) _
sendMessage = \State state, dest, body ->
    payload = encodeJSON {
        src: state.nodeId,
        dest,
        body: { body & msgId: state.msgId },
    }
    Stdout.line! payload
    Task.ok (State { state & msgId: state.msgId + 1 })

Payload body : {
    src : Str,
    dest : Str,
    body : body,
}

LoopState a : [WaitingForInit]a

run = \handleInput ->
    initialState : LoopState a
    initialState = WaitingForInit
    Task.loop!
        initialState
        (\state ->
            line = Stdin.line |> Task.result!

            when line is
                Ok lineStr ->
                    Stderr.line! lineStr

                    newState = handleInput! lineStr state
                    Task.ok (Step newState)

                Err (StdinErr EndOfFile) ->
                    Stderr.line! "EOF"

                    Task.ok (Done {})

                Err err ->
                    Task.err err
        )
