package away3d.materials
{
	import away3d.arcane;
	import away3d.cameras.lenses.*;
	import away3d.containers.*;
	import away3d.core.base.*;
	import away3d.core.draw.*;
	import away3d.core.utils.*;
	import away3d.events.*;
	
	import flash.display.*;
	import flash.geom.*;
	import flash.utils.*;
	
	use namespace arcane;
	
	/**
	 * Container for caching multiple bitmapmaterial objects.
	 * Renders each material by caching a bitmapData surface object for each face.
	 * For continually updating materials, use <code>CompositeMaterial</code>.
	 * 
	 * @see away3d.materials.CompositeMaterial
	 */
	public class CompositeMaterial extends BitmapMaterial
	{
		/** @private */
        arcane var _source:Object3D;
        /** @private */
        arcane override function updateMaterial(source:Object3D, view:View3D):void
        {
        	for each (var _material:LayerMaterial in materials)
        		_material.updateMaterial(source, view);
        	
        	if (_colorTransformDirty)
        		updateColorTransform();
        	
        	if (_bitmapDirty)
        		updateRenderBitmap();
        	
        	if (_materialDirty || _blendModeDirty)
        		updateFaces();
        	
        	_blendModeDirty = false;
        }
        /** @private */
        arcane override function renderTriangle(tri:DrawTriangle):void
        {
        	if (_surfaceCache) {
        		super.renderTriangle(tri);
        	} else {
	        	_source = tri.source;
	        	_session = _source.session;
	    		var level:int = 0;
	    		
	    		var _sprite:Sprite = _session.layer as Sprite;
	    		
	        	if (!_sprite || this != _session._material || _colorTransform || blendMode != BlendMode.NORMAL) {
	        		_sprite = _session.getSprite(this, level++);
	        		_sprite.blendMode = blendMode;
	        	}
	    		
	    		if (_colorTransform)
	    			_sprite.transform.colorTransform = _colorTransform;
	    		else
	    			_sprite.transform.colorTransform = _defaultColorTransform;
		        
	    		//call renderLayer on each material
	    		for each (var _material:LayerMaterial in materials)
	        		level = _material.renderLayer(tri, _sprite, level);
        	}
        }
        
		/** @private */
        arcane override function renderLayer(tri:DrawTriangle, layer:Sprite, level:int):int
        {
        	var _sprite:Sprite;
        	if (!_colorTransform && blendMode == BlendMode.NORMAL) {
        		_sprite = layer;
        	} else {
        		_source = tri.source;
        		_session = _source.session;
        		
        		_sprite = _session.getSprite(this, level++, layer);
	        	
	        	_sprite.blendMode = blendMode;
	        	
	    		if (_colorTransform)
	    			_sprite.transform.colorTransform = _colorTransform;
	    		else
	    			_sprite.transform.colorTransform = _defaultColorTransform;
        	}
    		
	    	//call renderLayer on each material
    		for each (var _material:LayerMaterial in materials)
        		level = _material.renderLayer(tri, _sprite, level);
        	
        	return level;
        }
        
		/** @private */
        arcane override function renderBitmapLayer(tri:DrawTriangle, containerRect:Rectangle, parentFaceMaterialVO:FaceMaterialVO):FaceMaterialVO
		{
			_faceMaterialVO = getFaceMaterialVO(tri.faceVO);
			
			//get width and height values
			_faceWidth = tri.faceVO.face.bitmapRect.width;
    		_faceHeight = tri.faceVO.face.bitmapRect.height;

			//check to see if bitmapContainer exists
			if (!(_containerVO = _containerDictionary[tri]))
				_containerVO = _containerDictionary[tri] = new FaceMaterialVO();
			
			//resize container
			if (parentFaceMaterialVO.resized) {
				parentFaceMaterialVO.resized = false;
				_containerVO.resize(_faceWidth, _faceHeight, transparent);
			}
			
			//pass on invtexturemapping value
			_faceMaterialVO.invtexturemapping = _containerVO.invtexturemapping = parentFaceMaterialVO.invtexturemapping;
			
			//call renderFace on each material
    		for each (var _material:LayerMaterial in materials)
        		_containerVO = _material.renderBitmapLayer(tri, containerRect, _containerVO);
			
			//check to see if face update can be skipped
			if (parentFaceMaterialVO.updated || _containerVO.updated) {
				parentFaceMaterialVO.updated = false;
				_containerVO.updated = false;
				
				//reset booleans
				_faceMaterialVO.invalidated = false;
				_faceMaterialVO.cleared = false;
				_faceMaterialVO.updated = true;
        		
				//store a clone
				_faceMaterialVO.bitmap = parentFaceMaterialVO.bitmap.clone();
				_faceMaterialVO.bitmap.lock();
				
				_sourceVO = _faceMaterialVO;
	        	
	        	//draw into faceBitmap
	        	if (_blendMode == BlendMode.NORMAL && !_colorTransform)
	        		_faceMaterialVO.bitmap.copyPixels(_containerVO.bitmap, _containerVO.bitmap.rect, _zeroPoint, null, null, true);
	        	else
					_faceMaterialVO.bitmap.draw(_containerVO.bitmap, null, _colorTransform, _blendMode);
	  		}
	  		
	  		return _faceMaterialVO;        	
		}
        private var _defaultColorTransform:ColorTransform = new ColorTransform();
		private var _width:Number;
		private var _height:Number;
		private var _surfaceCache:Boolean;
		private var _fMaterialVO:FaceMaterialVO;
		private var _containerDictionary:Dictionary = new Dictionary(true);
		private var _cacheDictionary:Dictionary = new Dictionary(true);
		private var _containerVO:FaceMaterialVO;
		private var _faceWidth:int;
		private var _faceHeight:int;
		private var _faceVO:FaceVO;
		
        private function onMaterialUpdate(event:MaterialEvent):void
        {
        	_materialDirty = true;
        }
        
		/**
		 * An array of bitmapmaterial objects to be overlayed sequentially.
		 */
		protected var materials:Array;
        
		/**
		 * @inheritDoc
		 */
		protected override function updateRenderBitmap():void
        {
        	_bitmapDirty = false;
        	
        	invalidateFaces();
        	
        	_materialDirty = true;
        }
        
		/**
		 * @inheritDoc
		 */
		protected override function getMapping(tri:DrawTriangle):Matrix
		{
			_faceVO = tri.faceVO.face.faceVO;
			
			if (_view.camera.lens is ZoomFocusLens)
        		_focus = tri.view.camera.focus;
        	else
        		_focus = 0;
			
			_faceMaterialVO = getFaceMaterialVO(_faceVO, tri.source, tri.view);
			
    		if (_faceMaterialVO.invalidated || _faceMaterialVO.updated) {
	    		_faceMaterialVO.updated = true;
	    		_faceMaterialVO.cleared = false;
	    		
	        	//check to see if face drawtriangle needs updating
	        	if (_faceMaterialVO.invalidated) {
	        		_faceMaterialVO.invalidated = false;
	        		
	        		//update face bitmapRect
	        		_faceVO.face.bitmapRect = new Rectangle(int(_width*_faceVO.minU), int(_height*(1 - _faceVO.maxV)), _faceWidth = int(_width*(_faceVO.maxU-_faceVO.minU)+2), _faceHeight = int(_height*(_faceVO.maxV-_faceVO.minV)+2));
	        		
					//update texturemapping
					_faceMaterialVO.invtexturemapping = tri.transformUV(this).clone();
					_faceMaterialVO.texturemapping = _faceMaterialVO.invtexturemapping.clone();
					_faceMaterialVO.texturemapping.invert();
					
	        		//resize bitmapData for container
	        		_faceMaterialVO.resize(_faceWidth, _faceHeight, transparent);
	        	}
        		
        		_fMaterialVO = _faceMaterialVO;
        		
	    		//call renderFace on each material
	    		for each (var _material:LayerMaterial in materials)
	        		_fMaterialVO = _material.renderBitmapLayer(tri, _bitmapRect, _fMaterialVO);
        		
        		_cacheDictionary[_faceVO] = _fMaterialVO.bitmap;
	        	
	        	_fMaterialVO.updated = false;
			}
        	
        	_renderBitmap = _cacheDictionary[_faceVO];
        	
        	//check to see if tri is generated
        	if (tri.generated) {
        		
        		//update texturemapping
				_texturemapping = tri.transformUV(this).clone();
				_texturemapping.invert();
				
				return _texturemapping;
        	}
			
    		return _faceMaterialVO.texturemapping;
        }
		
		/**
		 * Defines whether the caching bitmapData objects are transparent
		 */
		public var transparent:Boolean;
		
		/**
		 * Switches the rendering mode of layers from <code>Sprite</code> based to <code>Bitmap</code> based
		 */
    	public function get surfaceCache():Boolean
        {
        	return _surfaceCache;
        }
        
        public function set surfaceCache(val:Boolean):void
        {
        	_surfaceCache = val;
        	
        	_materialDirty = true;
        }
		
		/**
		 * Returns the width of the bitmapData being used as the material texture. 
		 */
		public override function get width():Number
		{
			return _width;
		}
		
		public function set width(val:Number):void
		{
			if (_width == val)
				return;
			
			_width = val;
			
			if (_width && _height)
				_bitmap = new BitmapData(_width, _height, true, 0x00FFFFFF);
			
			_bitmapRect = new Rectangle(0, 0, _width, _height);
		}
		
		/**
		 * Returns the height of the bitmapData being used as the material texture. 
		 */
		public override function get height():Number
		{
			return _height;
		}
		
		public function set height(val:Number):void
		{
			if (_height == val)
				return;
			
			_height = val;
			
			if (_width && _height)
				_bitmap = new BitmapData(_width, _height, true, 0x00FFFFFF);
			
			_bitmapRect = new Rectangle(0, 0, _width, _height);
		}
		
		/**
		 * Creates a new <code>CompositeMaterial</code> object.
		 * 
		 * @param	init	[optional]	An initialisation object for specifying default instance properties.
		 */
		public function CompositeMaterial(init:Object = null)
		{
            ini = Init.parse(init);
			
			width = ini.getNumber("width", 128);
			height = ini.getNumber("height", 128);
			
			super(_bitmap, ini);
			
			materials = ini.getArray("materials");
			
            
            for each (var _material:LayerMaterial in materials)
            	_material.addOnMaterialUpdate(onMaterialUpdate);
			
			transparent = ini.getBoolean("transparent", true);
			surfaceCache = ini.getBoolean("surfaceCache", false);
		}
		        
        public function addMaterial(material:LayerMaterial):void
        {
        	material.addOnMaterialUpdate(onMaterialUpdate);
        	materials.push(material);
        	
        	_materialDirty = true;
        }
        
        public function removeMaterial(material:LayerMaterial):void
        {
        	var index:int = materials.indexOf(material);
        	
        	if (index == -1)
        		return;
        	
        	material.removeOnMaterialUpdate(onMaterialUpdate);
        	
        	materials.splice(index, 1);
        	
        	_materialDirty = true;
        }
        
        public function clearMaterials():void
        {
        	var i:int = materials.length;
        	
        	while (i--)
        		removeMaterial(materials[i]);
        }
		
	}
}