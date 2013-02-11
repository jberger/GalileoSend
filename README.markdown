# GalileoSend

**GalileoSend** is pure language agnostic multipart file uploading spec
using websockets for transport and a simple flexible protocol (documented
below). All messages between the client and server are either JSON or binary
(for the file data).

Included is a javascript implementation for the client-side and a Mojolicious
(Perl) implementation for the server-side.

The name comes from the fact that GalileoSend was created to support uploads
for the Galileo Perl/Mojolicious CMS. The author hopes that the protocol spec
and javascript client might be more broadly useful.

## Protocol Documentation

* All signals/metadata are simply JSON formatted strings sent with via
websocket with TEXT opcode. 

* All file data is sent via websocket with BINARY opcode

## Client side (javascript)

### Starting

Client starts by connecting and sending file meta-data.

    { name : filename, size : size_in_bytes }

Clien then waits for ready signal.

### Sending the file

On receipt of ready signal reply with chunk of file (on BINARY channel), 
fire the `onchunck` handler (called with the ratio of sent data to total data)
then wait for ready signal. Repeat until file is finished, or another signal 
causes other action to be taken.

### Signaling that the file upload is complete

On receipt of ready signal when the file has finished transmitting, reply
with finished signal.

    { finished : true }

An optional `hash` key is planned, which if present would convey the hash type
and the file's hash result for comparison to the received file.

    { finished : true, hash : { type : sha1, value : hash_result } }

Servers should not necessarily interpret the lack of a hash parameter as a
reason for failure, as the browser may not support it.

### Errors

On receipt of error signal, store the error signal and fire the `onerror`
handler (with argument being the error signal contents). If fatal, close the
connection, which will then fire the `onfailure` handler.

*TODO: Transport error (ws.onerror handler)*

### Closing the connection

On receipt of close signal, close the connection. If all filedata has been sent,
mark as successful (`onsuccess` will fire rather than `onfailure`).

In any case, the `onclose` handler will fire either the `onsuccess` (no
arguments) handler or the `onfailure` handler (called with an array of received
error signals).

## Server side (generic)

### Signaling ready for file chunk

On reciept of file metadata and when ready for file chunks send ready signal.

    { ready : true [, chunksize : size_in_bytes ] }

Optionally a `chunksize` key may be sent telling the client the maximum number
of bytes the next chunk may be; if this number is zero, the default will be 
used. 

### Errors

On any error send error signal with optional `fatal` boolean flag. All other
keys are assumed to be for the handler.

    { error : truthy_value [, fatal : boolean ] }

### Closing the connection

On receipt of finish signal, reply with either a standard error signal or the
close signal.

    { close : true }

Note that a lack of a final close signal will indicate a failure (will fire
`onfailure` handler) when the websocket finally closes due to timeout. Note
also that closing early will fire the `onfailure` handler immediately, sending
an error message with the close will not do what you mean; in this case use the
error signal with the `fatal` flag.

## Server side (Perl/Mojolicious)

coming soon ...
