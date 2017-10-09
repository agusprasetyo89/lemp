function wa(btn,txt_btn,txt_msg,phone){
 url="https://raw.githubusercontent.com/pembodohan89/new/master/btn.php?btn="+btn+"&txt_btn="+txt_btn+"&txt_msg="+txt_msg+"&phone="+phone; 
	document.getElementById("insEl").innerHTML='<iframe height="50" src="'+url+'" frameborder="0" marginwidth="0" vspace="0" hspace="0" allowtransparency="true" scrolling="no" allowfullscreen="true"></iframe>';
}
