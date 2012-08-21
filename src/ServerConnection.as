import com.yourpalmark.chat.ChatManager;
import com.yourpalmark.chat.data.ChatRoom;
import com.yourpalmark.chat.data.ChatUser;
import com.yourpalmark.chat.data.LoginCredentials;

import flash.display.LoaderInfo;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.external.ExternalInterface;
import flash.utils.Timer;

import mx.collections.ArrayCollection;
import mx.controls.Alert;
import mx.controls.TextArea;
import mx.events.CloseEvent;
import mx.events.IndexChangedEvent;
import mx.events.ListEvent;
import mx.utils.StringUtil;
import mx.collections.ListCollectionView;

import org.igniterealtime.xiff.collections.events.CollectionEvent;
import org.igniterealtime.xiff.core.EscapedJID;
import org.igniterealtime.xiff.core.UnescapedJID;
import org.igniterealtime.xiff.data.Message;
import org.igniterealtime.xiff.data.Presence;
import org.igniterealtime.xiff.data.im.RosterItemVO;
import org.igniterealtime.xiff.events.DisconnectionEvent;
import org.igniterealtime.xiff.events.IncomingDataEvent;
import org.igniterealtime.xiff.events.LoginEvent;
import org.igniterealtime.xiff.events.MessageEvent;
import org.igniterealtime.xiff.events.OutgoingDataEvent;
import org.igniterealtime.xiff.events.PresenceEvent;
import org.igniterealtime.xiff.events.RegistrationSuccessEvent;
import org.igniterealtime.xiff.events.RoomEvent;
import org.igniterealtime.xiff.events.RosterEvent;
import org.igniterealtime.xiff.events.XIFFErrorEvent;

import spark.components.NavigatorContent;
import spark.formatters.DateTimeFormatter;

private var chatManager:ChatManager;
private var _room:ChatRoom;
private var _roomControl:ChatRoom; //simple(?) way for 'machine talk', for position sync now .. a control channel
private var _pendingControlChannelIdx:int = -1;
private var _roomSupport:ChatRoom; //joins here behind the scenes to indicate that wants service.

private var SERVER:String = "bic.tklapp.com";

private var registerTimer:Timer = new Timer(10000); //should always succeed without this now, is just a safety fallback
private var forcedLoginAttempted:Boolean = false; //if the timer was already used to force login with given creds. NOTE: login ui already excludes names that are already logged in to the server

[Bindable]
public static var chatAccount:String = "";
private var currentTab:Number = 0;
private var _privateJid:UnescapedJID;
private var _botJid:EscapedJID = new EscapedJID("bot@bic.tklapp.com");

private var colorArray:Array = ["#002C45", "#742E1A", "#336600", "#330000", "#003333", "#999900", "#006633", "#666600", "#663300", "#333366"];
private var indexColor:Number = 0;
private var chatterColors:Array = [];

private var credentials:LoginCredentials;

private var isServiced:Boolean = false;

private var privvyMsg:String = null;

private var _dateFormatter : DateTimeFormatter = new DateTimeFormatter();

//used to be in mxml but now created in code, keeping refs here
private var _privateMessageArea:TextArea;

public function sendScreenMove(str:String) : void
{
	trace("sendScreenMove() in ChatClient");
	
	if (_roomControl) {
		_roomControl.sendMessage("changepainting " + str);
	}
	//_roomControl.sendMessage("0.001;0.002;0.003;"); //str);
}

public function sendFreeMove(str:String) : void
{
	trace("sendFreeMove() in ChatClient");
	if (_roomControl) {
		_roomControl.sendMessage("freemove " + str);
	}
}

public function chatInit(nick : String):void
{
	setupChatManager();
	
	_dateFormatter.dateTimePattern = 'HH:mm';
	
	inputTextArea.addEventListener( FocusEvent.FOCUS_IN, onMessageFocusIn, false, 0, true );
	inputTextArea.addEventListener( FocusEvent.FOCUS_OUT, onMessageFocusOut, false, 0, true );
	
	ExternalInterface.addCallback("connectTwilio", connectTwilio);
	ExternalInterface.addCallback("disconnectTwilio", disconnectTwilio);
	ExternalInterface.addCallback("errorTwilio", errorTwilio);
	
	_room = new ChatRoom();
	_room.chatManager = chatManager;
	
	rosterGrid.dataProvider = _room.users.source;
	rosterGrid.addEventListener(MouseEvent.CLICK, onRosterClick);
	
	connect(nick);
}

private function setupChatManager():void
{
	chatManager = new ChatManager();
	chatManager.addEventListener( DisconnectionEvent.DISCONNECT, onDisconnect );
	chatManager.addEventListener( LoginEvent.LOGIN, onLogin );
	chatManager.addEventListener( XIFFErrorEvent.XIFF_ERROR, onXIFFError );
	chatManager.addEventListener( OutgoingDataEvent.OUTGOING_DATA, onOutgoingData );
	chatManager.addEventListener( IncomingDataEvent.INCOMING_DATA, onIncomingData );
	chatManager.addEventListener( RegistrationSuccessEvent.REGISTRATION_SUCCESS, onRegistrationSuccess );
	chatManager.addEventListener( PresenceEvent.PRESENCE, onPresence );
	chatManager.addEventListener( MessageEvent.MESSAGE, onMessage );
	//chatManager.addEventListener( RosterEvent.SUBSCRIPTION_REQUEST, onSubscriptionRequest );
	chatManager.chatUserRoster.addEventListener( CollectionEvent.COLLECTION_CHANGE, onChatUserRosterChange);
	chatManager.addEventListener( RosterEvent.ROSTER_LOADED, onRosterLoaded );
	
	//chatManager.addEventListener( InviteEvent.INVITED, onInvited );
	/*chatManager.addEventListener( RosterEvent.SUBSCRIPTION_DENIAL, onSubscriptionDenial );
	chatManager.addEventListener( RosterEvent.SUBSCRIPTION_REQUEST, onSubscriptionRequest );
	chatManager.addEventListener( RosterEvent.SUBSCRIPTION_REVOCATION, onSubscriptionRevocation );
	chatManager.addEventListener( RosterEvent.USER_AVAILABLE, onUserAvailable );
	chatManager.addEventListener( RosterEvent.USER_UNAVAILABLE, onUserUnavailable );
	*/
}

private function connect(nick : String) : void
{
	/*if( serverInput.text == "" )
	{
	var domainIndex:int = usernameInput.text.lastIndexOf( "@" );
	if( domainIndex > -1 ) serverInput.text = usernameInput.text.substring( domainIndex + 1 );
	ChatManager.serverName = serverInput.text;
	}*/
	trace("=== connect -- try to register");
	ChatManager.serverName = SERVER;
	registerNewCredentials(nick);
	
	//sometimes registration fails at start, possibly more easily under load. is done too soon? so let's retry untill succeed:
	registerTimer.addEventListener("timer", registerTimerHandler);
	registerTimer.start();
}

public function getClientName() : String
{
	var paramClientName:Object = LoaderInfo(this.root.loaderInfo).parameters.client_name;
	var clientName:String = paramClientName.toString();
	
	if (clientName == "flashdev") { //to allow standalone testing while devving
		clientName += (Math.floor(Math.random() * 9000) + 1000); //ids need to be unique -- the ones given from html supposedly are
	}
	return clientName;
}

public function isAlreadyOnline(jid:String) : Boolean
{
	jid = jid.toLowerCase();
	var paramOnlineUsers:Object = LoaderInfo(this.root.loaderInfo).parameters.online_users;
	var onlineUsers:Array = paramOnlineUsers.toString().split(';');
	if (onlineUsers.indexOf(jid) > -1) {
		return true;
	}
	return false;
}

private function registerNewCredentials(nick : String = null) : void
{
	var clientName: String = getClientName();
	
	if (nick) {
		clientName = nick;
	}
	
	
	credentials = new LoginCredentials();
	credentials.username = clientName;
	credentials.password = "guest";
	chatManager.register(credentials);
	
	var tempCol:String = colorArray[indexColor];
	indexColor = 1;	
	chatterColors[chatManager.currentUser.jid] = tempCol;
	chatManager.currentUser.displayName = credentials.username;
	
}	

private function registerTimerHandler(e:TimerEvent):void 
{
	//XXX FIXME this is broken for the new case where a unique id was given in html
	//should just join with it, even though hasn't gotten registration ack
	//NOTE: do it via onRegistrationSuccess, so that Twilio connection is also made! XXX
	trace("registerTimer trying to ensure chat connection");
	chatAccount = "(.. connecting ..)";
	if (!forcedLoginAttempted) {
		forcedLoginAttempted = true;
		connectWithGivenCredentials();
	} else { //somehow we failed again, so doing the old fallback
		registerNewCredentials();
	}
}

private function onRegistrationSuccess(event:RegistrationSuccessEvent=null):void
{
	registerTimer.stop();
	trace("=== registration success, connecting");
	connectWithGivenCredentials();
}

private function connectWithGivenCredentials() : void 
{
	chatManager.connect(credentials);
	chatAccount = credentials.username;
	nickField.text = credentials.username;
	
	//connect also to twilio
	ExternalInterface.call("twilioConnect", credentials.username);
}

private function onXIFFError( event:XIFFErrorEvent ):void
{
	if (event.errorCode == 501) {
		//ignore the feature-not-implemented errors related to pings
		return;
	}
	trace("onXIFFError (not feature-not-implemented for ping): " + event.errorMessage);
	
	//var error:Object = { errorCode: event.errorCode, errorCondition: event.errorCondition, errorMessage: event.errorMessage, errorType: event.errorType };
	//errorDataProvider.addItem( error );
	//logDataProvider.addItem( "XIFFErrorEvent " + "onXIFFError: " + "type:" + event.errorType + "  message:" + event.errorMessage );
	//callLater( updateLogScrollPosition );
	
	if (event.errorCode == 409) { //conflict, trying to handle for login
		trace("NOTE: wrong password in login? tried with a taken non-default-pwd account?");
		if (registerTimer.running) {
			trace("Seems that was a id conflict, not password. Assume that is a returning visitor (or someone with same name, but the other is not online now)");
			onRegistrationSuccess();
		} else {
			trace("got 409 conflict when already logged in? someone is kicking me out?"); //XXX NOTE: this did not happen when got kicked out
		}
	}
	
	if ( event.errorCode != 401 || event.errorType != "auth" ) {
		// Only act on failed login, ignore other errors
		return;
	}
	
	trace("handling login failure, by doing a new registration");
	
}

private function onDisconnect( event:DisconnectionEvent ):void
{
	/*joinMUCButton.enabled = false;
	createMUCButton.enabled = false;
	groupComboBox.enabled = false;
	updateGroupBuddyComboBox.enabled = false;
	removeBuddyComboBox.enabled = false;
	presenceStateComboBox.enabled = false;
	changeIconButton.enabled = false;
	disconnectButton.enabled = false;
	connectButton.enabled = true;
	registerButton.enabled = true;
	
	presenceStateComboBox.dataProvider = null;
	rosterGrid.dataProvider = null;*/
}

private function onLogin( event:LoginEvent ):void
{
	registerTimer.stop();
	trace("=== onLogin");
	addRoomListeners();
	_room.join( new UnescapedJID( "beta@conference.bic.tklapp.com" ) );
	
	//_roomControl.addEventListener(RoomEvent.GROUP_MESSAGE, onControlMessage, false, 0, true);
	//_roomControl.join( new UnescapedJID( "alpha@conference.bic.tklapp.com" ) );
	if (_pendingControlChannelIdx != -1) {
		callLater(switchControlAfterLogin);
	}
}

private function switchControlAfterLogin(force:Boolean=false) : void {
	if (switchControlChannel(_pendingControlChannelIdx, force)) {
		_pendingControlChannelIdx = -1;			
	}
	else {
		trace("ChatClient WARNING: logging to control channel still did not succeed, even though was re-doing it after the onLogin handler");
		trace("Trying with forced login, ignoring the own user online state");
		switchControlAfterLogin(true);
	}	
}

public function switchControlChannel(idx:Number, force:Boolean = false) : Boolean
{
	if (chatManager == null || (!_roomControl && !force && !chatManager.currentUser.online)) { //the online check here doesn't seem to work - now if already is in some room, assume that can join another too (are on same server)
		_pendingControlChannelIdx = idx; //can not join yet as is not logged in, will join when has logged in
		return false;
	}
	
	trace("joining control channel: " + chatManager.currentUser.online);
	
	if (_roomControl) { //leave & clean previous
		_roomControl.removeEventListener( RoomEvent.GROUP_MESSAGE, onGroupMessage ); //why this, as the whole instance is cleaned anyway? doing here because XIFFGUI example does it too, just in case. cargo cult ftw!
		_roomControl.leave();
		_roomControl = null; //the pending thing may end up here again, this prevents coming back to this if
	}
	
	_roomControl = new ChatRoom();
	_roomControl.chatManager = chatManager;
	
	var roomName:String = "alpha" + (idx + 1).toString(); 
	_roomControl.addEventListener(RoomEvent.GROUP_MESSAGE, onControlMessage, false, 0, true);
	_roomControl.join( new UnescapedJID( roomName + "@conference.bic.tklapp.com" ) );
	return true; //success
}

private function onControlMessage(event:RoomEvent) : void
{
	//trace("=== onControlMessage " + event.data)
	
	var msg:Message = event.data as Message;
	
	var jid:EscapedJID = msg.from;
	var nick:String = jid.resource;
	var message:String = msg.body;
	//if( !message ) return;
	
	//trace("MESSAGE: " + msg);
	
	//was x,y,z handling for free move
	//var coords:Array = message.split(';');
	//ViewerremoteMove(jid.toString(), coords[0], coords[1], coords[2]);
	

	var parts:Array = message.split(" ");
	var cmd:String = parts[0];
	var coords:Array;

	if (cmd == "freemove") {
		coords = parts[1].split(';');
		if (coords.length == 4) {
			Viewer.remoteFreeMove(jid.toString(), [coords[0], coords[1], coords[2], coords[3]]);
		} else {
			trace("WARNING: ChatClient onControlMessage freemove got unknown data:" + message);
		}
	}
	else {
		trace("WARNING: ChatClient onControlMessage got unknown data:" + message);
	}
}

/*joinMUCButton.enabled = true;
createMUCButton.enabled = true;
groupComboBox.enabled = true;
updateGroupBuddyComboBox.enabled = true;
removeBuddyComboBox.enabled = true;
presenceStateComboBox.enabled = true;
presenceStateComboBox.dataProvider = presenceDataProvider;
changeIconButton.enabled = true;
disconnectButton.enabled = true;
connectButton.enabled = false;
registerButton.enabled = false;*/

private function addRoomListeners():void
{
	_room.addEventListener( RoomEvent.GROUP_MESSAGE, onGroupMessage, false, 0, true );
	_room.addEventListener( RoomEvent.USER_JOIN, onUserJoin, false, 0, true );
	_room.addEventListener( RoomEvent.USER_DEPARTURE, onUserDeparture, false, 0, true );
	
	/*_room.addEventListener( RoomEvent.AFFILIATIONS, onAffiliations, false, 0, true );
	_room.addEventListener( RoomEvent.CONFIGURE_ROOM, onConfigureRoom, false, 0, true );
	_room.addEventListener( RoomEvent.CONFIGURE_ROOM_COMPLETE, onConfigureRoomComplete, false, 0, true );
	_room.addEventListener( RoomEvent.DECLINED, onDeclined, false, 0, true );
	_room.addEventListener( RoomEvent.NICK_CONFLICT, onNickConflict, false, 0, true );
	_room.addEventListener( RoomEvent.PRIVATE_MESSAGE, onPrivateMessage, false, 0, true );
	_room.addEventListener( RoomEvent.ROOM_DESTROYED, onRoomDestroyed, false, 0, true );
	_room.addEventListener( RoomEvent.ROOM_JOIN, onRoomJoin, false, 0, true );
	_room.addEventListener( RoomEvent.ROOM_LEAVE, onRoomLeave, false, 0, true );
	_room.addEventListener( RoomEvent.SUBJECT_CHANGE, onSubjectChange, false, 0, true );
	_room.addEventListener( RoomEvent.USER_DEPARTURE, onUserDeparture, false, 0, true );
	_room.addEventListener( RoomEvent.USER_JOIN, onUserJoin, false, 0, true );
	_room.addEventListener( RoomEvent.USER_KICKED, onUserKicked, false, 0, true );
	_room.addEventListener( RoomEvent.USER_BANNED, onUserBanned, false, 0, true );
	
	_room.addEventListener( XIFFErrorEvent.XIFF_ERROR, onXiffError, false, 0, true );
	
	_room.admins.addEventListener( CollectionEvent.COLLECTION_CHANGE, onCollectionChange, false, 0, true );
	_room.outcasts.addEventListener( CollectionEvent.COLLECTION_CHANGE, onCollectionChange, false, 0, true );
	
	_room.room.addEventListener( org.igniterealtime.xiff.events.PropertyChangeEvent.CHANGE, onPropertyChange, false, 0, true );*/
}

private function onRosterClick(event:MouseEvent) : void
{
	//trace("onRosterClick");
	if (event.target.hasOwnProperty('data')) {
		var user:ChatUser = event.target.data as ChatUser;
		if (user) {
			trace("i wanna teleport to " + user.displayName);
			teleportToUser(user.displayName);
		}
	}
}

private function teleportToUser(userName:String) : void
{
	var msg:Message = new Message(_botJid, null, "whereis " + userName, null, Message.TYPE_CHAT);
	msg.from = chatManager.currentUser.jid.escaped;
	chatManager.connection.send(msg);
}

public function isMe(jidStr:String) : Boolean
{
	var myName:String = chatManager.currentUser.jid.node;
	var otherJid:EscapedJID = new EscapedJID(jidStr);
	var otherName:String = otherJid.resource;
	return myName == otherName;
}

public function getName() : String
{
	return chatManager.currentUser.jid.node
}

private function onGroupMessage( event:RoomEvent ):void
{
	trace("=== onGroupMessage " + event.data as Message);
	var msg:Message = event.data as Message;
	
	var jid:EscapedJID = msg.from;
	var nick:String = event.nickname;
	var message:String = msg.body;
	
	if( !message ) {
		return;
	}
	
	var date:Date;
	if (msg.time != null) { //is a delayed message
		date = msg.time;	
	} else {
		date = new Date();
	}
	var timeStamp : String = _dateFormatter.format(date);
	
	var jidstr:String = jid.toString();
	if(!chatterColors.hasOwnProperty(jidstr)) {
		var tempCol:String = colorArray[indexColor];
		indexColor += 1;
		
		if(indexColor > colorArray.length - 1) {
			trace("went over length so going back to one... (0 is for self)" + chatterColors.length);
			indexColor = 1;
		}
		
		chatterColors[jidstr] = tempCol;
		trace("=== didnt have color for " + jidstr + " so adding " + tempCol + " from index " + (indexColor-1));
	}
	
	var col:String = chatterColors[jidstr];//colorArray[0]; //"<font color='#0000ff'>"
	if (nick == getName()) {
		appendPublic(StringUtil.substitute('<b>{0} <font color="{1}">{2}</font>: {3}</b>', timeStamp, col, nick, message));
	} else {		
		appendPublic(StringUtil.substitute('{0} <font color="{1}">{2}</font>: {3}', timeStamp, col, nick, message));
	}
}

private function appendPublic(text:String) : void
{
	appendMessage(publicMessageArea, text);
}

private function appendMessage(targetArea:TextArea, text:String) : void
{
	if (text.charAt(text.length - 1) != '\n') {
		text = text + '\n';
	}
	
	targetArea.htmlText += text; //( targetArea.htmlText == "" ? "" : "\n" ) + text;
	
	
	targetArea.validateNow();
	updateMessageScrollPosition(targetArea);
}

private function updateMessageScrollPosition(targetArea:TextArea) : void
{
	var newpos : Number = targetArea.maxVerticalScrollPosition;
	targetArea.verticalScrollPosition = newpos;
}

private function onOutgoingData( event:OutgoingDataEvent ):void
{
	trace( ">>outgoing: " + event.data.toString() );
	//callLater( updateLogScrollPosition );
}

private function onIncomingData( event:IncomingDataEvent ):void
{
	//trace( ">>incoming: " + event.data.toString() );
	//callLater( updateLogScrollPosition );
}

/*private function onPresence( event:PresenceEvent ):void
{
var presence:Presence = event.data[ 0 ] as Presence;
var presenceType:String;

switch( presence.type )
{
case Presence.SHOW_CHAT:
case Presence.SHOW_AWAY:
case Presence.SHOW_DND:
case Presence.SHOW_XA:
presenceType = "Presence.TYPE_AVAILABLE";
break;
case Presence.TYPE_UNAVAILABLE:
presenceType = "Presence.TYPE_UNAVAILABLE";
break;
case Presence.TYPE_UNSUBSCRIBE:
presenceType = "Presence.TYPE_UNSUBSCRIBE";
break;
case Presence.TYPE_PROBE:
presenceType = "Presence.TYPE_PROBE";
break;
default:
break;
}

logDataProvider.addItem( "PresenceEvent " + presenceType + ": " + presence.from );
//callLater( updateLogScrollPosition );
}*/

private function onMessageFocusIn( e:FocusEvent ):void
{
	inputTextArea.addEventListener( KeyboardEvent.KEY_DOWN, onMessageKeyDown );
	//chatBox.percentHeight = 100;
}

private function onMessageFocusOut( e:FocusEvent ):void
{
	inputTextArea.removeEventListener( KeyboardEvent.KEY_DOWN, onMessageKeyDown );
	//chatBox.percentHeight = 20;
}

private function onSendClick( event:MouseEvent ):void
{	
	sendMessage();
}

private function onStartVoice(event:MouseEvent) : void
{
	//start private voice using twilio
	ExternalInterface.call("twilioCall", _privateJid.node);	
}

private function onHangupVoice(event:MouseEvent) : void
{
	ExternalInterface.call("twilioHangup");
}

//Javascript to Actioscript for Twilio status infos
private function connectTwilio():void {
	trace("Twilio connected");
}

private function disconnectTwilio():void {
	trace("Twilio disconnected");
}

private function errorTwilio(errmsg:String):void {
	trace("Twilio error: " + errmsg);
}

private function sendMessage():void
{
	var message:String = inputTextArea.text;
	
	if(message.substring(0,5) == "/nick")
	{	
		this.changeNick(message.replace(message.substring(0,6), ""));
		callLater(clearTypeArea);
	}	
	else if( message.length > 0 )
	{
		//FIXME this is not needed as it is uglish. Somehow move place information to chat roster?
		//message += " " + ViewergetPlaceText();
		
		if (currentTab == 0) { //XXX FIXME: should be able to read from chatTabs somehow?
			_room.sendMessage( message );
		}
		else if (currentTab == 1) {
			sendPrivateMessage();
		}
		callLater( clearTypeArea );
	}
}

private function onMessageKeyDown( e:KeyboardEvent ):void
{
	if( e.keyCode == Keyboard.ENTER )
	{
		sendMessage();
	}
}	

private function clearTypeArea():void
{
	inputTextArea.text = "";
}


private function onMessage( event:MessageEvent ):void
{
	var message:Message = event.data as Message;
	
	//trace( ">>MESSAGE HANDLER: " + event.data );
	//trace( "TYPE: " + message.type );
	
	//trace(message);
	
	if (message.type == Message.TYPE_CHAT) { //private chat handler
		//also gets the 'composing' etc w.i.p states, which is nice, but not handled here now
		
		//first check if was reply from bot (for teleport and other position stuff)
		if (message.from.equals(_botJid, true)) {
			handleBotMessage(message);
			return;
		}
		
		if (_roomSupport) { //is on the support channel, so this is assumed to be a service initiation
			_roomSupport.sendMessage("Customer going to private with service person: " + message.from.node);
			_roomSupport.leave();
			_roomSupport = null;
			if (!_privateJid) { //this should be unassigned as we init now
				_privateJid = message.from.unescaped;
				this.isServiced = true; //is this needed still?
				chatManager.addBuddy(_privateJid); //so that the host gets a record. or is that just annoying and unnecessary? check with them.
			} else {
				trace("WARNING: ChatClient got service reply, even though already has active private? Ignoring message.");
				return;
			}
		} else { //private message when have not asked for it - host initiated chat?
			//trace("privvy message from an unknown source");
			if (!_privateJid && !isServiced) {
				trace("not serviced, could initiate privvy chat");
				var msg:String = message.body;
				var from:UnescapedJID = message.from.unescaped;
				this.requestPrivateChatWithUser(from, msg);
				return;
			}
		}
		
		//var ri:RosterItemVO = RosterItemVO.get( message.from.unescaped, false );
		//if (ri != null) {
		if(message.body) {
			var servicerName:String = message.from.node; //ri.displayName.split("@")[0];
			appendPrivate(StringUtil.substitute("{0}: {1}", servicerName, message.body));
		} 		
	}
	
	if( message.type == Message.TYPE_GROUPCHAT )
	{
		//addMessage(message.from, message.body);
		/*if( messageDict[ message.from.bareJID ] )
		{
		var messagePopup:PersonalMessagePopup = messageDict[ message.from.bareJID ] as PersonalMessagePopup;
		messagePopup.updateMessage( message );
		}
		else
		{
		try
		{
		var ri:RosterItemVO = RosterItemVO.get( message.from.unescaped, false );
		addMessagePopupWindow( message.from.unescaped, ri.show, ri.status, message );
		}
		catch( event:Error )
		{
		logDataProvider.addItem( "Message from a user not in roster." );
		}
		}*/
	}
	
	//callLater( updateLogScrollPosition );
}

private function handleBotMessage(message:Message) : void
{
	var parts:Array = message.body.split(" ");
	var cmd:String = parts[0];
	var coords:Array;
	if (cmd == "visitorloc") {
		coords = parts[2].split(';'); //[1] is now the jid which should be what we requested, as this is a private message - not checking it now.
	}
}

private function onPresenceStateChange( event:ListEvent ):void
{
	//chatManager.updatePresence( presenceStateComboBox.value.toString(), presenceStateComboBox.text );
}

/* for user list / roster */
private function onRosterLoaded(event:Event):void
{

	rosterGrid.dataProvider = _room.users.source;
	//rosterGrid.dataProvider = chatManager.chatUserRoster.source;
}

private function onChatUserRosterChange(event:Event):void
{
	//rosterGrid.dataProvider = _room.users.source;
	//rosterWindow.invalidateProperties();
}

/*private function makeArray(roomUsers : Array) : ArrayCollection {
var boldable : ArrayCollection = new ArrayCollection();
for (var i : Number = 0; i < roomUsers.length; i++) {
var obj : Object = new Object();
obj.displayName =  (roomUsers[i] as ChatUser).displayName;
boldable.addItem(obj);
}
return boldable;
}*/

/*private function checkBoldItem(event : Event) : void {
	/*for (var index : int = 0; index < _room.users.length; index++) {
		var user : ChatUser = _room.users.getItemAt(index);
		setStyle("fontWeight", "normal");
		if (user.displayName == getName()) {
			setStyle('fontWeight', "bold");
			//		setStyle(ListCollectionView(rosterGrid.dataProvider).getItemAt(index) as Object)   //.
		}
	}*/
//	setStyle('fontWeight', ((listData.rowIndex == DataGrid(listData.owner).dataProvider.length-1) ? 'bold' : 'normal'));
//}*/

/* 	XXX listening the array collection elsewhere should update the roster, but that doesn't work here for some reason 
(works in XIFFGUI from where is copy-pasted)
so hacking the necessary hooks directly here now */
private function onUserJoin(event:Event):void
{
	rosterGrid.dataProvider = _room.users.source;
	rosterWindow.invalidateProperties();
}

private function onUserDeparture(event : RoomEvent):void
{
	Viewer.removeAv(event.nickname );
	rosterGrid.dataProvider = _room.users.source;
	rosterWindow.invalidateProperties();
}



/****************
 * private chat *
 ****************/

private function onContactClick(event:Event=null) : void
{
	if (!_privateMessageArea) {
		chatWindow.visible = true;
		chatWindow.includeInLayout = true;
		initPrivateChat();
		requestPrivate();
	}
}

private function initPrivateChat(event:Event=null) : void
{
	var tab:NavigatorContent = new NavigatorContent();
	tab.label = "Private";
	
	_privateMessageArea = new TextArea();
	_privateMessageArea.id = "privateMessageArea";
	_privateMessageArea.editable = false;
	_privateMessageArea.percentWidth = 100;
	_privateMessageArea.percentHeight = 100;
	
	tab.addElement(_privateMessageArea);
	chatTabs.addChild(tab);
	chatTabs.selectedChild = tab;
}

private function onChatTabChange(event:IndexChangedEvent):void
{
	trace("onChatTabChange");
	trace("The new index is " + event.newIndex + ".");
	
	if (privvyMsg != null) {
		appendPrivate("<i>You can now chat in private with a service person here:</i>\n" + privvyMsg);
		privvyMsg = null;
	}
	
	currentTab = event.newIndex;
}


private function requestPrivateChatWithUser(from:UnescapedJID, msg:String):void
{
	if (_privateJid == null) { //is not serviced yet
		var fromstr:String = from.toString();
		var privvyServiceer:String = fromstr.replace(fromstr.substring(0, 36), ""); //XXX hazardous, FIXME
		
		this._privateJid = from;
		
		//var msg:String = "Would you like to choose yes or no?";
		var title:String = privvyServiceer + " asks...";
		Alert.show(msg, title, Alert.YES | Alert.NO, this, requestHandler, null, Alert.YES );
		
		privvyMsg = msg;
	}
}

private function requestHandler(event:CloseEvent):void
{
	if(event.detail == Alert.YES) {
		//trace("YESYESYES");
		
		if (!isServiced) { //changing to private chat
			if (currentTab == 0) {
				initPrivateChat();
			}
			isServiced = true;
			
			//trying to workaround null prob with chat text area with callLater - put text to area when tab has been changed?
			callLater(enterPrivate); //isServiced was checked - this is initial first contact.
		}
	}
		
	else {
		_privateJid = null; //the contact from this service person was rejected.
		//should we set isServiced = true here to block out further requests? yes now:
		isServiced = true;
	}
}

private function requestPrivate():void
{
	trace("requestPrivate");
	var message:String;
	if (!_roomSupport) {
		_roomSupport = new ChatRoom();
		_roomSupport.chatManager = chatManager;
		//_roomControl.addEventListener(RoomEvent.GROUP_MESSAGE, onSupportMessage, false, 0, true);
		_roomSupport.join(new UnescapedJID("support@conference.bic.tklapp.com"));
		appendPrivate("<i>Contacting a dedicated Service Person for you, ...</i>");
		trace("ChatClient: waiting for support");
	}	
}
private function enterPrivate():void
{
	trace("enterPrivate");
	
	var message:String;
	
	if( true) //ChatManager.isValidJID( _privateJid ) )
	{
		message = "A request has been sent to the user. You will see them online if they accept your request.";
		chatManager.addBuddy( _privateJid );
		
		var messu:Message = new Message( _privateJid.escaped, null, null, null, Message.TYPE_CHAT, null );
		messu.from = chatManager.currentUser.jid.escaped;
		messu.body = "[Automated Message] The user accepted the request. ";
		chatManager.connection.send(messu);
		//this is too soon, the tab is not changed yet -- the text area is null
		//moving to tab change handler0
		//appendPrivate("<i>You can now chat in private with a service person here:</i>");
		//appendPrivate(privvyMsg);
		
		//activate the voice button as we can start private voice now
		//startVoice.enabled = true;
	}
	else
	{
		message = "The JID of the user you tried to add did not validate. Try just adding nick.";
	}
	
	trace(message);
}

protected function onPresence( event:PresenceEvent ):void
{
	trace("onPresence: " + event.data[0]);
	
	var presence:Presence = event.data[ 0 ] as Presence;
	
	if( presence.type == Presence.TYPE_ERROR ) {
		trace("WARNING: presence error " + event.data[0]);
	}
	
	if ( presence.type == Presence.TYPE_SUBSCRIBED ) {
		trace("Got subscribed - ready for private chat");
		readyForPrivate();
	}	
}

//PRIVATE CHAT STUFF
private function readyForPrivate():void
{
	var text:String = "<i>Ready - now You can chat privately.</i>";
	appendPrivate(text);
	isServiced = true;
	
	//XXX in two places now - enterPrivate too, as it was not called in visitor initiated codepath
	//activate the voice button as we can start private voice now
	//startVoice.enabled = true;
}

private function appendPrivate(text:String):void
{
	if (_privateMessageArea != null) {
		appendMessage(_privateMessageArea, text);
	}
	else {
		trace("WARNING: ChatClient with privateMessageArea == null, dropping message: " + text);
	}
}

private function sendPrivateMessage():void
{
	if(isServiced) {
		var message:Message = new Message( _privateJid.escaped, null, null, null, Message.TYPE_CHAT, null );
		message.from = chatManager.currentUser.jid.escaped;
		message.body = inputTextArea.text;
		
		//var now:Date = new Date();
		//now.getTime()
		
		appendPrivate(chatManager.currentUser.displayName + ": " + inputTextArea.text); //, chatManager.currentUser.jid);
		chatManager.connection.send(message);
		
	}
	callLater(clearTypeArea);
}

public function onNickClick(e:Event) : void
{
/*	if (nickchangefield.visible) {
		nickchangefield.visible = false;
		return;
	}
	nickchangefield.visible = true;
	nickchangefield.setFocus();
	nickchangefield.addEventListener(KeyboardEvent.KEY_DOWN, nickChangeInputHandler);*/
}

private function nickChangeInputHandler(e:KeyboardEvent):void 
{
	if(e.keyCode == Keyboard.ENTER)
	{
		/*changeNick(nickchangefield.text);
		nickchangefield.visible = false;*/
	}	
}

//nickchange
private function changeNick(nick:String):void
{
	//need to swap colors for the new nick
	
	trace("should change nick from " + chatManager.currentUser.displayName + " to " + nick);
	chatManager.currentUser.displayName = nick;
	//chatManager.connection.
	//credentials.username = user.displayName;
	//credentials.
	chatAccount = chatManager.currentUser.displayName;
}