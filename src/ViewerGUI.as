package
{
	import flash.events.Event;
	
	import mx.collections.ArrayCollection;
	import mx.collections.Sort;
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.core.UIComponent;	
	import mx.managers.PopUpManager;

	
	public class ViewerGUI
	{
		///[Embed(source="assets/help.png")]
		public static var HelpTexture : Class;
		
		private static var _arrows : Array = new Array();
		
		public static function drawTriangle(next:Boolean) : UIComponent
		{
			var height:Number = 25;
			
			var triangle:UIComponent = new UIComponent();
			triangle.graphics.beginFill(0xDDDDDD, 0.75);
			triangle.graphics.lineStyle(3, 0xAAAAAA, 1.0, true);
			if (next) {
				triangle.graphics.lineTo(-height, -height);
				triangle.graphics.lineTo(-height, height);
				triangle.graphics.lineTo(0, 0);
				triangle.toolTip = "Goto next point of interest";
			} else {
				triangle.graphics.lineTo(height, -height);
				triangle.graphics.lineTo(height, height);
				triangle.graphics.lineTo(0, 0);
				triangle.toolTip = "Goto previous point of interest";
			}
			triangle.graphics.endFill();
			_arrows.push(triangle);
			return triangle;
		}
	
		public static function showHelp(evt:Event=null) : void
		{	
			Alert.buttonWidth = 100;
			Alert.yesLabel = "Close Help";
			
			Alert.show("", "Help", Alert.YES, null, function(event : Event) : void { FlexGlobals.topLevelApplication.helpbutton.selected=false; }, HelpTexture);
			
			// Set the labels back to normal:
			Alert.yesLabel = "Yes";
		}
		
		public static function showUi(show:Boolean) : void
		{
			FlexGlobals.topLevelApplication.chatBox.visible = show;
			FlexGlobals.topLevelApplication.infoZone.visible = show;
		}
		
		public static function showArrows(show : Boolean) : void
		{
			for (var i : int = 0; i  < _arrows.length; i++) {
				_arrows[i].visible = show;
			}
		}
	}
}
