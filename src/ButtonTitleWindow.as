//from http://userflex.wordpress.com/2011/05/05/add-titlewindow-buttons/

package
{
	import flash.events.MouseEvent;
	
	import mx.containers.TitleWindow;
	import mx.controls.Button;
	import mx.core.FlexGlobals;

	public class ButtonTitleWindow extends TitleWindow
	{
		private var helpButton : Button;
		private var _closeButton : Button;
		
		public function ButtonTitleWindow ()
		{
			title = "Button TitleWindow";
			showCloseButton = false;
		}
		
		private function get closeButton () : Button
		{
			if (! _closeButton)
			{
				for (var i : int = 0; i < titleBar.numChildren; ++ i)
				{
					if (titleBar.getChildAt (i) is Button &&
						titleBar.getChildAt (i) != helpButton)
					{
						_closeButton = titleBar.getChildAt (i) as
							Button;
					}
				}
			}
			
			return _closeButton;
		}
		
		override protected function createChildren () : void
		{
			super.createChildren ();
			
			if (! helpButton)
			{
				helpButton = new Button ();
				helpButton.label = "Change nick";
				helpButton.toolTip = "Change your chat nick";
				helpButton.focusEnabled = false;
				helpButton.setStyle ("paddingTop", 4);
				helpButton.addEventListener(MouseEvent.CLICK, FlexGlobals.topLevelApplication.onNickClick);
				//titleBar.addChild (helpButton);
				helpButton.owner = this;
			}
		}
		
		override protected function layoutChrome (w : Number,
												  h : Number) : void
		{
			super.layoutChrome (w, h);
			
			var width_ : Number = helpButton.getExplicitOrMeasuredWidth ();
			var height_ : Number = helpButton.getExplicitOrMeasuredHeight ();
			
			var x_ : Number = 150; //closeButton.x – width_;
			var y_ : Number = 3; //closeButton.y – Math.floor((height_ – closeButton.height) * 0.50);
			
			helpButton.setActualSize (width_, height_);
			helpButton.move (x_, y_);
		}
		
	}
}