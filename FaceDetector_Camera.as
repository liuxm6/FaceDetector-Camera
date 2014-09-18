package 
{
	import com.quasimondo.bitmapdata.CameraBitmap;
	import com.adobe.images.JPGEncoder;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.net.URLLoaderDataFormat;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.system.Security;
	import flash.system.SecurityPanel;

	import jp.maaash.ObjectDetection.ObjectDetector;
	import jp.maaash.ObjectDetection.ObjectDetectorEvent;
	import jp.maaash.ObjectDetection.ObjectDetectorOptions;

	import mx.utils.Base64Encoder;
	import mx.utils.Base64Decoder;

	public class FaceDetector_Camera extends Sprite
	{

		private var detector:ObjectDetector;
		private var options:ObjectDetectorOptions;

		private var view:Sprite;
		private var faceRectContainer:Sprite;

		private var camera:CameraBitmap;
		private var detectionMap:BitmapData;
		private var drawMatrix:Matrix;
		private var scaleFactor:int = 4;
		private var w:int = 226;
		private var h:int = 268;

		private var lastTimer:int = 0;
		private var loader:URLLoader;
		private var flg:int = 1;
		private var opt:int = 0;
		private var notice:TextField = new TextField  ;
		private var base64_probe:String;
		private var sfz:String;
		private var flow:int = 0;

		public function FaceDetector_Camera()
		{
			ExternalInterface.addCallback("setFlag",setFlag);
			ExternalInterface.addCallback("setOptionFace",setOptionFace);
			ExternalInterface.addCallback("setSfz",setSfz);
			ExternalInterface.addCallback("setFlowflag",setFlowflag);
			initUI();
			initDetector();

		}
		/*初始化图像界面*/
		private function initUI():void
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			notice.width = w;
			notice.height = 20;
			notice.autoSize = "center";
			notice.y = h / 2 - 20;
			view = new Sprite  ;
			addChild(view);

			var Cam:Camera = Camera.getCamera();
			if ((Cam == null))
			{
				notice.text = "请检查摄像头是否开启!";
				view.addChild(notice);
			}
			else
			{
				if (Cam.muted)
				{
					Security.showSettings(SecurityPanel.PRIVACY);
				}
				var c_name:String = Cam.name.toLocaleLowerCase();
				if (c_name.indexOf("vcam") >= 0 || c_name.indexOf("softcam") >= 0 || c_name.indexOf("9158") >= 0 || c_name.indexOf("0755") >= 0 || c_name.indexOf("camsplitter") >= 0)
				{
					notice.text = "请使用真实摄像头!";
					view.addChild(notice);
				}
				else
				{
					camera = new CameraBitmap(w,h,15);
					camera.addEventListener(Event.RENDER,cameraReadyHandler);
					view.addChild(new Bitmap(camera.bitmapData));
					detectionMap = new BitmapData((w / scaleFactor),h / scaleFactor,false,0);
					drawMatrix = new Matrix((1 / scaleFactor),0,0,1 / scaleFactor);
					faceRectContainer = new Sprite  ;
					view.addChild(faceRectContainer);
				}
			}
		}
		/*摄像头准备处理*/
		private function cameraReadyHandler(event:Event):void
		{
			detectionMap.draw(camera.bitmapData,drawMatrix,null,"normal",null,true);
			detector.detect(detectionMap);
		}
		/*初始化检测器*/
		private function initDetector():void
		{
			detector = new ObjectDetector  ;
			var options:ObjectDetectorOptions = new ObjectDetectorOptions  ;
			options.min_size = 30;
			detector.options = options;
			detector.addEventListener(ObjectDetectorEvent.DETECTION_COMPLETE,detectionHandler);
		}
		/*往图像上面画矩形*/
		private function detectionHandler(e:ObjectDetectorEvent):void
		{
				var g:Graphics = faceRectContainer.graphics;
				g.clear();
				if(flow == 1){
				if (e.rects)
				{
					g.lineStyle(2,0x15F930);
					e.rects.forEach(function( r :Rectangle, idx :int, arr :Array ) :void {
					g.drawEllipse( r.x * scaleFactor, r.y * scaleFactor, r.width * scaleFactor, r.height * scaleFactor+20 );
					var jpgEncoder:JPGEncoder = new JPGEncoder(90);
					var ba :ByteArray = jpgEncoder.encode(camera.bitmapData);
					var base64Encoding:Base64Encoder = new Base64Encoder();
					base64Encoding.encodeBytes(ba,0,ba.length);
					base64_probe = base64Encoding.toString();
					if(flg == 1 && sfz){
						flg = 0;
						if(opt == 0){
							ExternalInterface.call("setLoadStart");
							predictFace(base64_probe);
						}
						else{
							ExternalInterface.call("tackFace",sfz,base64_probe);
						}
					}
				});
			}
			}
		}
		/*人脸识别对比*/
		private function predictFace(base64_probe:String):void
		{
			loader = new URLLoader  ;
			var param:Object = root.loaderInfo.parameters;
			var sfz:String = sfz;
			var servlet:String = param["servlet"];
			var request:URLRequest = new URLRequest(servlet);
			request.method = URLRequestMethod.POST;
			var variables:URLVariables = new URLVariables  ;
			variables._sfz = sfz;
			variables._bp = base64_probe;
			request.data = variables;
			loader.dataFormat = URLLoaderDataFormat.VARIABLES;
			loader.addEventListener(Event.COMPLETE,handleServerResponse);
			loader.load(request);
		}
		/*人脸识别对比请求处理*/
		private function handleServerResponse(e:Event):void
		{
			if (loader.data)
			{
				ExternalInterface.call("setLoadEnd");
				if (loader.data == "OT-E")
				{
					ExternalInterface.call("setError","服务器繁忙！OT-E");
				}
				else if (loader.data == "OT-NOFACE")
				{
					ExternalInterface.call("setError","没有人脸模板照片！NOFACE");
				}
				else if (loader.data.error == "0X00000000")
				{
					ExternalInterface.call("jsProcess",loader.data);
				}
				else
				{
					ExternalInterface.call("setError",loader.data.error);
				}
				ExternalInterface.call("jsProcess","01");
			}
			else{
				ExternalInterface.call("setError","服务器繁忙！");
				flg = 1;
			}
		}
		private function setFlag(i:int):void
		{
			flg = i;
		}
		private function setOptionFace(i:int):void
		{
			opt = i;
		}
		private function setSfz(s:String):void
		{
			sfz = s;
		}
		private function setFlowflag(i:int):void
		{
			flow = i;
		}
	}
}