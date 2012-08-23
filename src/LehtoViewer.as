package
{		
	import away3d.animators.PathAnimator;
	import away3d.cameras.Camera3D;
	import away3d.containers.ObjectContainer3D;
	import away3d.containers.Scene3D;
	import away3d.containers.View3D;
	import away3d.core.base.Object3D;
	import away3d.core.math.MathConsts;
	import away3d.entities.Mesh;
	import away3d.entities.Sprite3D;
	import away3d.events.LoaderEvent;
	import away3d.paths.QuadraticPath;
	import away3d.lights.DirectionalLight;
	import away3d.loaders.Loader3D;
	import away3d.loaders.parsers.Parsers;
	import away3d.materials.ColorMaterial;
	import away3d.materials.TextureMaterial;
	import away3d.materials.lightpickers.StaticLightPicker;
	import away3d.primitives.CubeGeometry;
	import away3d.primitives.SkyBox;
	import away3d.primitives.SphereGeometry;
	import away3d.textures.BitmapCubeTexture;
	import away3d.textures.BitmapTexture;
	import away3d.textures.VideoTexture;
	
	import flash.display.BitmapData;
	import flash.display.LoaderInfo;
	import flash.display.Sprite;
	import flash.display.StageScaleMode;
	import flash.events.*;
	import flash.external.ExternalInterface;
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	import flash.net.URLRequest;
	import flash.system.LoaderContext;
	import flash.text.AntiAliasType;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.ui.Keyboard;
	import flash.utils.getTimer;
	
	import mx.collections.ArrayCollection;
	import mx.containers.Canvas;
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.managers.PopUpManager;
	import mx.utils.StringUtil;
	
	import spark.components.TextInput;
	import spark.components.TitleWindow;
	
	public class LehtoViewer extends Canvas
	{
		//Skybox textures
		[Embed(source="assets/skybox/rex_sky_back.png")]
		private var SkyBack : Class;
		[Embed(source="assets/skybox/rex_sky_bot.png")]
		private var SkyBot : Class;
		[Embed(source="assets/skybox/rex_sky_front.png")]
		private var SkyFront : Class;
		[Embed(source="assets/skybox/rex_sky_left.png")]
		private var SkyLeft : Class;
		[Embed(source="assets/skybox/rex_sky_right.png")]
		private var SkyRight : Class;
		[Embed(source="assets/skybox/rex_sky_top.png")]
		private var SkyTop : Class;
		
		private var _camera : Camera3D;
		private var _mapEntity : Mesh;
		private var _view : View3D;
		private var _viewDirty : Boolean = false;
		private var _scene : Scene3D;
		private var _directionalLight1 : DirectionalLight;
		private var _time : int;
		
		private var _loginWindow : TitleWindow
		
		private var _mouseIsDown : Boolean = false;
		private var _mouseMoved : Boolean = true;
		private var _lastMousePos:Array = [0, 0];
		private var _lastMouseDelta:Array = [0,0];
		private var _keysDown:Array = [];
		private var _mouseWheelDelta:Number = 0;
		
		private var _POIIndex:Number = 0;
		private var _animator:PathAnimator;
		
		private var _animatorRemotes:ArrayCollection = new ArrayCollection();
		private var _animationProgress:Number = 0.0;
		private var _animationTurnProgress:Number = 0;
		private var _animationTargetRotMatrix:Matrix3D;
		private var _animationOrigRotMatrix:Matrix3D;
		private var _animationSpeed:Number = 0.05;
		private var _animationInProgress:Boolean = false;
		
		private var _prevPOIIndex:Number = 0;
		
		private var _presenceObjects:Array = []; //avatars
		private var _remoteWatchers:Array = []; //info of remote client presences per painting
		private var _testObjectMaterial:ColorMaterial;
		private var _testObject:Mesh;
		private var _avatarMaterial:ColorMaterial;
		private var _animationTarget:Object3D;
		private var _avatarMesh:ObjectContainer3D;
		private var _avatarYOffset:Number = -1.5 //-1 for centered ball; //for pelinappula: -1.5
		private var _avatarMaterials : Array = new Array();
		private var _avatarMaterialIndex : Number = 0; 
		
		//free move networking
		private var FREEMOVEINTERVAL : Number = 1000;
		private var _moveDirty:Boolean = false;
		private var _movePrevTime:Number = 0;
		
		private var _presenceGeometry:SphereGeometry; //XXX is this used anymore? see makeShape or makeAvatar
		
		private var _videoTexture:VideoTexture;;
		
		private var _nextButton:Sprite;
		private var _prevButton:Sprite;
		
		private var _staticSceneLoader : Loader3D;
		private var _meshReady:Boolean = false;
		private var _toBeLoaded:Array = new Array();
			
		private var _baseUrl : String;
		
		public function LehtoViewer()
		{
			if (stage) {
				init();
			} else {
				addEventListener(Event.ADDED_TO_STAGE, init);
			}
		}
		
		private function init(e : Event = null) : void
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			//set focus to this app using javascript
			if(ExternalInterface.available)
			{
				ExternalInterface.call("eval", "document.getElementById('" + ExternalInterface.objectID + "').tabIndex=0");
				ExternalInterface.call("eval", "document.getElementById('" + ExternalInterface.objectID + "').focus()");
			}
			
			var loaderInfo : LoaderInfo = LoaderInfo(FlexGlobals.topLevelApplication.root.loaderInfo);
			_baseUrl = loaderInfo.parameters.baseurl;
			
			// Setup the stage
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			_time = getTimer();
			
			//Adjust camera near and far
			_camera = new Camera3D();
			_camera.lens.near = 0.1;
			_camera.lens.far = 2000;
			_camera.position = Constants.startPos;
			
			_view = new View3D(null, _camera);
			_view.backgroundColor = 0xEEEEEE;
			this.rawChildren.addChild(_view);
			
			// draw the test cube for animation and hide it below the map FIXME can be removed in the final
			_testObjectMaterial = new ColorMaterial(0xFF0000);
			_testObject = makeCube();
			_testObject.position = new Vector3D(0, -100, 0);
			_testObject.visible = false;			
			
			//_lightPicker = new StaticLightPicker([_directionalLight1]);
			
			//Assign animation target
			_animationTarget = _camera;//testObject;
			
			_presenceGeometry = new SphereGeometry(0.3);
			
			//FIXME we don't need debug stuff in the final version 
			//this.rawChildren.addChild(new AwayStats(_view));
			
			stage.addEventListener(Event.ENTER_FRAME, handleEnterFrame);
			
			_directionalLight1 = new DirectionalLight();
			_directionalLight1.diffuse = 0.7;
			_directionalLight1.specular = 0.3;
			_directionalLight1.ambient = 1.0;
			
			_view.scene.addChild(_directionalLight1);
			
			//Load Balloon
			Parsers.enableAllBundled();
			_staticSceneLoader = new Loader3D();
			_staticSceneLoader.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onSceneMeshComplete);
			//var scenefile:String = "ball_noplanes.obj";
			
			var loaderInfo : LoaderInfo = LoaderInfo(FlexGlobals.topLevelApplication.root.loaderInfo);
			var scenefilelocation:String = loaderInfo.parameters.scenefilelocation;
			_staticSceneLoader.load(new URLRequest(scenefilelocation));
			
			//load av mesh
			//var avfile:String = "pelinappula.obj";
			var avfile:String = "pelinappula.obj";
			var avLoader:Loader3D = new Loader3D();
			avLoader.addEventListener(LoaderEvent.RESOURCE_COMPLETE, 
				function(e:LoaderEvent):void {
					var loader:Loader3D = e.target as Loader3D;
					_avatarMesh = loader;
					_view.scene.addChild(loader);
				
				});
			avLoader.load(new URLRequest("assets/" + avfile));
			
			//Add skyBox
			addSky();
			
			// Setup resize handler
			stage.addEventListener(Event.RESIZE, resizeHandler);
			resizeHandler(); // Good to run the resizeHandler to ensure everything is in its place
			
			//initialize per-painting watcher info
			var galnum:int = Constants.POIPositions.length;
			for (var i:int = 0; i < galnum; i++) {
				_remoteWatchers[i] = [];
				for (var j:int = 0; j < 12; j++) {
					_remoteWatchers[i].push(new ArrayCollection());
				}
			}
			
			// Create a non-modal TitleWindow container.
			_loginWindow = PopUpManager.createPopUp(this, LoginForm, true) as TitleWindow;
			_loginWindow.closeButton.visible = false;
			//			loginWindow["loginButton"].addEventListener(MouseEvent.CLICK, login);
			_loginWindow["loginName"].setFocus();
			_loginWindow["loginName"].text = "";
			_loginWindow["loginName"].addEventListener(KeyboardEvent.KEY_DOWN, 
				function(event : KeyboardEvent) : void { 
					if (event.keyCode == Keyboard.ENTER) 
						login(event); 
				});
			
			PopUpManager.centerPopUp(_loginWindow);
			
			trace("Done init.");
		}
		
		public function login(event : Event = null) : void
		{
			var target : LoginForm = event.currentTarget.owner;
			var nameinput : TextInput = target["loginName"]
			var nick : String = StringUtil.trim(nameinput.text);
			var error : String = null;
			
			if (nick == "") {					
				error = "Please enter a username";
			} else if (nick.indexOf(" ") != -1 || nick.indexOf("@") != -1 || nick.indexOf("/") != -1) {
				error = "Username may not contain space or special characters.";
			} else if (FlexGlobals.topLevelApplication.isAlreadyOnline(nick)) {
				error = "Someone is already logged in with the given name: " + nick;
			}
			
			if (error != null) {
				Alert.yesLabel = "OK";
				Alert.show(error, "Error in login", Alert.YES);
				
				// Set the labels back to normal:
				Alert.yesLabel = "Yes";
				return;
			}
			
			trace("Login in with nick", nick);
			//start chat - it now gets the id param from flashvars, which can be read only after .. has been added to stage (see http://www.ultrashock.com/forum/viewthread/103022/)
			//chat must be started before galleries are joined, as is used for presence
			FlexGlobals.topLevelApplication.chatInit(nick);
			
			//next step - does the user want autopilot / demo mode / guided tour / slideshow mode?
			nameinput.visible = false;
			//_loginWindow.closeButton.visible = true;
			toggleInputHandlers(true);
			PopUpManager.removePopUp(_loginWindow);
		}
		
		public function toggleInputHandlers(add : Boolean) : void
		{
			if (add) {
				//Keyboard handlers
				stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown);
				stage.addEventListener(KeyboardEvent.KEY_UP, keyUp);
				
				//Mouse input
				this.stage.addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
				this.stage.addEventListener(MouseEvent.MOUSE_UP, mouseUp);
				this.stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMove);
				this.stage.addEventListener(MouseEvent.MOUSE_WHEEL, mouseWheel);
				
			} else {
				//Keyboard handlers
				stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyDown);
				stage.removeEventListener(KeyboardEvent.KEY_UP, keyUp);
				
				//Mouse input
				this.stage.removeEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
				this.stage.removeEventListener(MouseEvent.MOUSE_UP, mouseUp);
				this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMove);
				this.stage.removeEventListener(MouseEvent.MOUSE_WHEEL, mouseWheel);
			}
		}
		
		private function makeCube() : Mesh
		{
			var ob:Mesh = new Mesh(new CubeGeometry(0.5, 0.5, 0.5), _testObjectMaterial);
			_view.scene.addChild(ob);
			return ob;
		}
		
		private function makeSphere(avatarMaterial:ColorMaterial, nameToTag:String) : Mesh
		{
			var lightPicker:StaticLightPicker;
			lightPicker = new StaticLightPicker([_directionalLight1]);
			avatarMaterial.lightPicker = lightPicker;
			
			var ob:Mesh = new Mesh(_presenceGeometry.clone(), avatarMaterial);
			
			if (nameToTag) { //own av doesn't get name label now
				addNameTag(ob, nameToTag);
			}
			
			_view.scene.addChild(ob);
			return ob;
		}
		
		private function makeAvatar(nameToTag:String) : Object3D
		{
			/*var avatarMaterial:ColorMaterial = new ColorMaterial(0x65955E); //22DD99);
			var lightPicker:StaticLightPicker;
			lightPicker = new StaticLightPicker([_directionalLight1]);
			avatarMaterial.lightPicker = lightPicker;*/
			//avatarMaterial.smooth = true;
			
			//XXX FIXME: either embed the mesh to the swf or handle not-loaded-yet gracefully here
			if (_avatarMesh == null) {
				trace("No avatar mesh yet");
				return null;
			}
			var ob:Object3D = _avatarMesh.clone();
			
			if (nameToTag) { //own av doesn't get name label now
				addNameTag(ob as ObjectContainer3D, nameToTag);
			}
			
			//ob.material = avatarMaterial;
			_view.scene.addChild(ob as ObjectContainer3D);
			return ob;	
		}
		
		private function addNameTag(ob:ObjectContainer3D, nameToTag:String) : void
		{
			var fmt : TextFormat = new TextFormat();
			fmt.font = "Arial";
			fmt.size = 12;
			fmt.color = 0xFFFFFF;
			fmt.align = TextFormatAlign.CENTER;
			var tf : TextField = new TextField();
			tf.text = nameToTag;
			tf.width = 128;
			tf.height = 16;
			
			tf.antiAliasType = AntiAliasType.ADVANCED;
			tf.sharpness = -100;
			tf.wordWrap = true
			tf.setTextFormat(fmt);
			
			var rect : Sprite = new Sprite();
			rect.graphics.beginFill(0x000000, 0.65);
			rect.graphics.drawRoundRect(0, 0, 128,16, 8, 8);
			rect.graphics.endFill();
			
			var bdata : BitmapData = new BitmapData(128, 16, true, 0);
			bdata.draw(rect);
			bdata.draw(tf);
			
			var tagMaterial : TextureMaterial = new TextureMaterial(new BitmapTexture(bdata), true, true, true);
			tagMaterial.alphaBlending = true;
			var nameTag : Sprite3D = new Sprite3D(tagMaterial, 1, 0.18);
			nameTag.y = 0.9;
			ob.addChild(nameTag);
		}
		
		private function ensureRemoteAvatar(idstr:String) : Object3D
		{
			var ob:Object3D;
			if (!_presenceObjects.hasOwnProperty(idstr)) {
				//check if is self -- own av is now shown identically to others, via server etc.
				var mat:ColorMaterial;
				var nameToTag:String;
				if (FlexGlobals.topLevelApplication.isMe(idstr)) {
					//mat = _testObjectMaterial;
					nameToTag = null; //no nametag for self, especially to not occlude view in freemove
				} else {
					//mat = new ColorMaterial(0x65955E);
					nameToTag = idstr.split('/')[1] //muc idstrs are format: mucname/name
					if (nameToTag.substring(0, 7) == "massbot") {
						nameToTag = null; //no nametags for bots either. hopefully not too confusing, perhaps nice .. see real ppl from labels
					}
				}
				ob = makeAvatar(nameToTag);
				if (ob == null) {
					return null;
				}
				//ob = makeSphere(mat, nameToTag);		
				_view.scene.addChild(ob as ObjectContainer3D);
				_presenceObjects[idstr] = ob; 
			}
			
			ob = _presenceObjects[idstr];
			return ob;
		}
		
		public function remoteFreeMove(idstr:String, toArr:Array) : void
		{
			//XXX FIXME: remove from previous gallery-screen visitors slot. perhaps by mover sending a ChangePainting to -1 first?
			
			_viewDirty = true;
			var ob:Object3D = ensureRemoteAvatar(idstr);
			if (ob == null) {
				return;
			}
			var to:Vector3D = new Vector3D(toArr[0], toArr[1], toArr[2]);
			var rot:Number = toArr[3];
			to.y += _avatarYOffset;
			ob.rotationY = rot;
			
			var animator:PathAnimator = linearAnimator(ob, to);
			animator.target.name = "freemove";
			animator.alignToPath = false; //true;
			animator.lookAtObject = null;
			_animatorRemotes.addItem(animator);
			/*ob.x = to[0];
			ob.y = to[1] - 0.5; //+ _avatarYOffset;
			ob.z = to[2];*/
		}
		
		private function addSky():void
		{
			var cubeTexture:BitmapCubeTexture = new BitmapCubeTexture(new SkyRight().bitmapData, new SkyLeft().bitmapData, new SkyTop().bitmapData, new SkyBot().bitmapData, new SkyFront().bitmapData, new SkyBack().bitmapData);
			//trace("SKY TRANSPARENT: " + cubeTexture.negativeX.transparent);
			var skyBox:SkyBox = new SkyBox(cubeTexture);
			_view.scene.addChild(skyBox);
		}
		
		private function resizeHandler(e:Event=null):void
		{
			_viewDirty = true;
			
			_view.width = Math.max(50, stage.stageWidth);
			_view.height = Math.max(50, stage.stageHeight);
		}
		
		
		private function itemIndexToPlace(index : int) : int	
		{
			return (index + 6) % 12;       	
		}
		
		private function onSceneMeshComplete(ev : LoaderEvent) : void
		{
			_viewDirty = true;
			
			trace("Load Complete");
			var cont : ObjectContainer3D;
			cont = _staticSceneLoader;
			
			var logoLoaderContext:LoaderContext = new LoaderContext();
			logoLoaderContext.checkPolicyFile = true;
			
			for (var i:int = 0; i < cont.numChildren; i++) {
				var mesh:Mesh = Mesh(cont.getChildAt(i));
				for (var j:int = 0; j < Constants.POIPositions.length; j++) {
					var clone:Mesh = mesh.clone() as Mesh;
					clone.position = new Vector3D(Constants.POIPositions[j][0], Constants.POIPositions[j][1], Constants.POIPositions[j][2]);
					_view.scene.addChild(clone);
				}
			}
			_meshReady = true;
		}
		
		private function keyDown(e:KeyboardEvent):void
		{
			var key:uint = e.keyCode;	
			for (var i:int = 0; i < _keysDown.length; i++) {
				if (_keysDown[i] == key) {
					return;
				}
			}       
			_keysDown.push(key);     
		}
		
		private function keyUp(e:KeyboardEvent):void
		{
			var key:uint = e.keyCode;	
			var newDown:Array = []
			for (var i:int = 0; i < _keysDown.length; i++) {
				
				if (_keysDown[i] != key) {
					newDown.push(_keysDown[i]);
				}
			}		
			_keysDown = newDown;
			
		}
		
		private function mouseMove(e:MouseEvent):void
		{       
			_lastMouseDelta = [_lastMousePos[0] - e.stageX, _lastMousePos[1] - e.stageY];
			_lastMousePos = [e.stageX, e.stageY];
			_mouseMoved = true;
		}
		
		private function mouseDown(e:MouseEvent) : void 
		{
			_viewDirty = true; //to make raycasts / mouse picking work when otherwise skipping rendering as cam is stationary
			_mouseIsDown = true;
		}
		
		private function mouseUp(e:MouseEvent) : void 
		{
			_viewDirty = true; //to make raycasts / mouse picking work when otherwise skipping rendering as cam is stationary
			_mouseIsDown = false;
		}
		
		private function mouseWheel(e:MouseEvent):void
		{
			_mouseWheelDelta = e.delta;	
		}
		
		private function handleEnterFrame(e : Event) : void {
			var time : int = getTimer();
			var dt : Number = time - _time;
			_time = time;
			
			if (_mouseMoved) {
				_viewDirty = true;
				_mouseMoved = false;
			}
			
			var key : uint;
			
			var moved:Boolean;
			for (var i : Number = 0; i < _keysDown.length; i++) {
				moved = true; //NOTE: this borks if multiple keys are pressed and last one of them is not a movement key. but who would do that?
				key = _keysDown[i];
				// if the key is still pressed, just keep on moving
				switch(key) {
					case Keyboard.RIGHT:
						_camera.yaw(0.05 * dt); 
						break;
					case Keyboard.LEFT:
						_camera.yaw(-0.05 * dt);
						break;
					case Keyboard.UP:
					case Keyboard.W:        
						_camera.moveForward(0.005 * dt); 
						break;
					case Keyboard.DOWN:
					case Keyboard.S:
						_camera.moveBackward(0.005 * dt);
						break;
					case Keyboard.A:
						_camera.moveLeft(0.005 * dt);
						break;i
					case Keyboard.D:
						_camera.moveRight(0.005 * dt); 
						break;
					default:
						moved = false;
				}
				
				if (moved) {
					_viewDirty = true;
					_moveDirty = true;
				}
			}
			
			
		/*	if (_animatorRemotes.length > 0) { //_animationInProgress2) {
				_viewDirty = true; //XXX FIXME: optimally would only dirty if the movements affect view -- not if the objects are e.g. behind camera
				//var animsdone:ArrayCollection.<Path
Animator> = new Vector.<PathAnimator>();
				var animsdone:ArrayCollection = new ArrayCollection();
				
				for each (var animator:PathAnimator in _animatorRemotes) {
					//_animationProgress += _animationSpeed * dt;
					/*if (animator.target.visible()) {
					_viewDirty = true;
					}
					animator.updateProgress(animator.progress + (_animationSpeed * dt));
					var lookPos:Vector3D;
					var targetdata:Array;
					var targetPaintingIdx:int;
					targetdata = animator.target.name.split(';'); //paintingIdx;slot
					targetPaintingIdx = Number(targetdata[0]);
					if (animator.target.name != "freemove" && targetPaintingIdx >= 0) {
						lookPos = Constants.POIPositions[targetPaintingIdx];
						lookPos.y = animator.target.y;
						animator.target.lookAt(lookPos);
					}
					//trace(animator.progress);
					//trace("Animation progress", _animationProgress, "change", _animationSpeed * dt);
					if (animator.progress >= 1) {
						if (animator.target.name != "freemove") {
							//NOTE: uses targetdata and targetPaintingIdx which were gotten above for lookAt now too
							var slot:int = Number(targetdata[1]);
							var here:ArrayCollection = _remoteWatchers[_galleryIndex][targetPaintingIdx]; //[remoteG][remoteP];
							if (here && here.length > 1) {
								//var slot:int = here.getItemIndex(animator.target);
								var newpos:Vector3D = animator.target.position;
								
								//first set rotation so that rightVector is correct for being in a row
								
								var radiusVector:Vector3D = _galleryLocation.subtract(newpos);
								radiusVector.y = 0;
								
								var angle:Number = Math.acos((newpos.x - _galleryLocation.x) / radiusVector.length);							
								animator.target.rotationY = (angle * 180) / Math.PI;
								
								//newpos.y = newpos.y + (slot / 3);
								var offset:Vector3D = animator.target.forwardVector; //err something weird with av rots now. .rightVector;
								if (slot % 2) {
									slot = -slot;
								}
								offset.scaleBy(slot / 2);
								newpos = newpos.add(offset);
								animator.target.position = newpos;
								
								if (targetPaintingIdx != -1) {
									lookPos = Constants.POIPositions[targetPaintingIdx];
									lookPos.y = animator.target.y;
									animator.target.lookAt(lookPos);
									_testObject.position = lookPos;
								}
							}
						}	
						//trace("remoteAnimator done.");
						animsdone.addItem(animator);
					}
				}
				
				for each (var done_animator:PathAnimator in animsdone) {
					//trace(_animatorRemotes);
					_animatorRemotes.removeItemAt(_animatorRemotes.getItemIndex(done_animator)); //XXX FIXME: could just use the index from iteration above, but that might be a little hairy with the js array weirdness(?)
				}
			}*/
			
			if (_animationInProgress) {
				_viewDirty = true;
				if (_animationTurnProgress <= 1.0) {
					_animationTurnProgress += 0.0025 * dt;
					//trace("Animation turn progress", _animationTurnProgress);
					var temp:Matrix3D = _animationOrigRotMatrix.clone();
					temp.interpolateTo(_animationTargetRotMatrix, _animationTurnProgress);
					_animationTarget.transform = temp;
				} else {
					_animationProgress += _animationSpeed * dt;
					_animator.updateProgress(_animationProgress);
					//trace("Animation progress", _animationProgress, "change", _animationSpeed * dt);
					//removing disabled now to ensure that anim is completed always with low (eg 3) FPS
					if (_animationProgress >= 1.0) {
						_animator.updateProgress(1);
						trace("cameraAnimator done.");
						_animationInProgress = false;
					}
				}
			} else {
				while (_toBeLoaded.length > 0) {
					var mapTile:Mesh = _toBeLoaded.pop()
					trace("loaded map from array", mapTile.x, mapTile.y, mapTile.z);
					_mapEntity.addChild(mapTile);
					_viewDirty = true;
				}
			}
			if (_viewDirty) {
				_view.render();
				_viewDirty = false;
			}
			
			if (_moveDirty && (time - _movePrevTime) > FREEMOVEINTERVAL) {
				var pos:Vector3D = _camera.position;
				var front:Vector3D = _camera.forwardVector;
				front.scaleBy(2);
				pos = pos.add(front);
				var camRotY:Number = Math.atan2(_camera.forwardVector.x, _camera.forwardVector.z);
				//_camera.eulers.y //is between -90 & 90, WTF?
				FlexGlobals.topLevelApplication.sendFreeMove(StringUtil.substitute("{0};{1};{2};{3}", pos.x, pos.y, pos.z, camRotY * MathConsts.RADIANS_TO_DEGREES));
				_moveDirty = false;
				_movePrevTime = time;
			}
		}
		
		private function showAvs(show:Boolean):void
		{
			for each (var av:ObjectContainer3D in _presenceObjects) {
				av.visible = show;
			}
		}
		
		public function removeAv(nick : String) : void
		{
			this._presenceObjects // FIXME SUPERMAN!
		}
		
		private function linearAnimator(animtarget:Object3D, to:Vector3D) : PathAnimator
		{

			
			var start:Vector3D = animtarget.position;
			var middle:Vector3D = to;
		    var pathPoints : Vector.<Vector3D> = new Vector.<Vector3D>(start, middle, to);
		    
			var animationPath : QuadraticPath = new QuadraticPath(pathPoints);			
			return new PathAnimator(animationPath, animtarget, null, false);
		}
		
		//network sending
		private function sendMoveMessage() : void
		{
			FlexGlobals.topLevelApplication.sendScreenMove(StringUtil.substitute("{0};{1};{2};{3}", _prevPOIIndex,  _POIIndex));
		}
	}	
}