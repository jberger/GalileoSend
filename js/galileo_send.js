function GalileoSend (param) {
  var ws = new WebSocket(param.url);
  var file = param.file;
  var filedata = { name : file.name, size : file.size };

  var chunksize = param.chunksize || 250000;
  var slice_start = 0;
  var end = filedata.size;
  var finished = false;
  var success = false;  // set to true on completion
  var error_messages = [];

  ws.onopen = function(){ ws.send(JSON.stringify(filedata)) };

  ws.onmessage = function(e){
    var status = JSON.parse(e.data);

    // got close signal
    if ( status.close ) {
      if ( finished ) {
        success = true;
      }
      ws.close();
      return;
    }

    // server reports error
    if ( status.error ) {
      if ( param.onerror ) {
        param.onerror( status );
      }
      error_messages.push( status );
      if ( status.fatal ) {
        ws.close();
      }
      return;
    }

    // anything else but ready signal is ignored
    if ( ! status.ready ) {
      return;
    }

    // upload already successful, inform server
    if ( finished ) {
      ws.send(JSON.stringify({ finished : true }));
      return;
    }

    // server is ready for next chunk
    var slice_end = slice_start + ( status.chunksize || chunksize );
    if ( slice_end >= end ) {
      slice_end = end;
      finished = true;
    }
    ws.send( file.slice(slice_start,slice_end) );
    if ( param.onchunk ) {
      param.onchunk( slice_end / end );  // send ratio completed
    }
    slice_start = slice_end;
    return;
  };

  ws.onclose = function () { 
    if ( success ) {
      if ( param.onsuccess ) {
        param.onsuccess();
      }
      return;
    }

    if (error_messages.length == 0) {
      error_messages[0] = { error : 'Unknown upload error' };
    }

    if ( param.onfailure ) {
      param.onfailure( error_messages );
    } else {
      console.log( error_messages );
    }
  }
}

