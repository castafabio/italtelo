import consumer from "./consumer"

consumer.subscriptions.create("DownloadChannel", {
  connected() {
    // Called when the subscription is ready for use on the server
    // console.log("Connected to the room!");
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    // console.log("Recieving:")
    // console.log(data.id)
    // var url = '/stocks/' + data.id + '/send_label';
    // $.getJSON(url, function(json){
    //   var download_link = json['download_link'];
    //   console.log(download_link);
    //   var a = document.createElement('a');
    //   a.style.display = 'none';
    //   a.href = download_link;
    //   a.download = 'etichetta.pdf';
    //   document.body.appendChild(a);
    //   a.click();
    //   window.URL.revokeObjectURL(url);
    // });
  }
});
