package away3d.materials
{
	import away3d.core.vos.FaceVO;
	import away3d.arcane;
	import away3d.cameras.lenses.*;
	import away3d.containers.*;
	import away3d.core.base.*;
	import away3d.core.render.*;
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
        arcane function getContainerVO(faceVO:FaceVO, source:Object3D = null, view:View3D = null):FaceMaterialVO
        {
        	source; view;
        	
        	//check to see if faceMaterialVO exists
			if ((_containerVO = _containerDictionary[faceVO]))
        		return _containerVO;
        	
        	return _containerDictionary[faceVO] = new FaceMaterialVO();
        }
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
        arcane override function renderTriangle(priIndex:uint, viewSourceObject:ViewSourceObject, renderer:Renderer):void
        {
        	if (_surfaceCache) {
        		super.renderTriangle(priIndex, viewSourceObject, renderer);
        	} else {
	        	_source = viewSourceObject.source;
	        	_session = renderer._session;
	        	_faceVO = renderer.primitiveElements[priIndex];
	        	
				_generated = renderer.primitiveGenerated[priIndex];
				
				_startIndex = renderer.primitiveProperties[priIndex*9];
				_screenVertices = viewSourceObject.screenVertices;
				
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
	        		level = _material.renderLayer(priIndex, viewSourceObject, renderer, _sprite, level);
        	}
        }
        
		/** @private */
        arcane override function renderLayer(priIndex:uint, viewSourceObject:ViewSourceObject, renderer:Renderer, layer:Sprite, level:int):int
        {
        	var _sprite:Sprite;
        	if (!_colorTransform && blendMode == BlendMode.NORMAL) {
        		_sprite = layer;
        	} else {
        		_source = viewSourceObject.source;
        		_session = renderer._session;
        		
        		_sprite = _session.getSprite(this, level++, layer);
	        	
	        	_sprite.blendMode = blendMode;
	        	
	    		if (_colorTransform)
	    			_sprite.transform.colorTransform = _colorTransform;
	    		else
	    			_sprite.transform.colorTransform = _defaultColorTransform;
        	}
    		
	    	//call renderLayer on each material
    		for each (var _material:LayerMaterial in materials)
        		level = _material.renderLayer(priIndex, viewSourceObject, renderer, _sprite, level);
        	
        	return level;
        }
        
		/** @private */
        arcane override function renderBitmapLayer(priIndex:uint, viewSourceObject:ViewSourceObject, renderer:Renderer, containerRect:Rectangle, parentFaceMaterialVO:FaceMaterialVO):FaceMaterialVO
		{
			_faceVO = renderer.primitiveElements[priIndex];
			_faceMaterialVO = getFaceMaterialVO(_faceVO, viewSourceObject.source, renderer._view);
			
			//get width and height values
			_faceWidth = _faceVO.face.bitmapRect.width;
    		_faceHeight = _faceVO.face.bitmapRect.height;

			//check to see if bitmapContainer exists
			_containerVO = getContainerVO(_faceVO, viewSourceObject.source, renderer._view);
			
			//resize container
			if (parentFaceMaterialVO.resized) {
				parentFaceMaterialVO.resized = false;
				_containerVO.resize(_faceWidth, _faceHeight, transparent);
			}
			
			//pass on invtexturemapping value
			_faceMaterialVO.invtexturemapping = _containerVO.invtexturemapping = parentFaceMaterialVO.invtexturemapping;
			
			//call renderFace on each material
    		for each (var _material:LayerMaterial in materials)
        		_containerVO = _material.renderBitmapLayer(priIndex, viewSourceObject, renderer, containerRect, _containerVO);
			
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
		private var _faceX:int;
		private var _faceY:int;
		private var _faceWidth:int;
		private var _faceHeight:int;
        private var _bRect:Rectangle;
        private var _minU:Number;
        private var _maxU:Number;
        private var _minV:Number;
        private var _maxV:Number;
        private var _index:Number;
        private var _uv:UV;
        private var _u:Number;
        private var _v:Number;
        
        private function onMaterialUpdate(event:MaterialEvent):void
        {
        	_materialDirty = true;
        }
        
		/**
		 * An array of bitmapmaterial objects to be overlayed sequentially.
		 */
		protected var materials:Array;
        
        protected override function transformUV(faceVO:FaceVO):Matrix
        {
            
            if (_uvs[0] == null || _uvs[1] == null || _uvs[2] == null)
                return null;

            _u0 = width * _uvs[0]._u;
            _u1 = width * _uvs[1]._u;
            _u2 = width * _uvs[2]._u;
            _v0 = height * (1 - _uvs[0]._v);
            _v1 = height * (1 - _uvs[1]._v);
            _v2 = height * (1 - _uvs[2]._v);
      
            // Fix perpendicular projections
            if ((_u0 == _u1 && _v0 == _v1) || (_u0 == _u2 && _v0 == _v2)) {
            	if (_u0 > 0.05)
                	_u0 -= 0.05;
                else
                	_u0 += 0.05;
                	
                if (_v0 > 0.07)           
                	_v0 -= 0.07;
                else
                	_v0 += 0.07;
            }
    
            if (_u2 == _u1 && _v2 == _v1) {
            	if (_u2 > 0.04)
                	_u2 -= 0.04;
                else
                	_u2 += 0.04;
                	
                if (_v2 > 0.06)           
                	_v2 -= 0.06;
                else
                	_v2 += 0.06;
            }
            
        	_invtexmapping.a = _u1 - _u0;
        	_invtexmapping.b = _v1 - _v0;
        	_invtexmapping.c = _u2 - _u0;
        	_invtexmapping.d = _v2 - _v0;
            _invtexmapping.tx = _u0 - faceVO.face.bitmapRect.x;
            _invtexmapping.ty = _v0 - faceVO.face.bitmapRect.y;
            
            return _invtexmapping;
        }
        
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
		protected override function getMapping(priIndex:uint, viewSourceObject:ViewSourceObject, renderer:Renderer):Matrix
		{
			if (_view.camera.lens is ZoomFocusLens)
        		_focus = _view.camera.focus;
        	else
        		_focus = 0;
			
			_faceMaterialVO = getFaceMaterialVO(_faceVO, _source, _view);
			
    		if (_faceMaterialVO.invalidated || _faceMaterialVO.updated) {
	    		_faceMaterialVO.updated = true;
	    		_faceMaterialVO.cleared = false;
	    		
	        	//check to see if face drawtriangle needs updating
	        	if (_faceMaterialVO.invalidated) {
	        		_faceMaterialVO.invalidated = false;
	        		
	        		//calculate max/min U/V
	        		_minU = Infinity;
	            	_maxU = -Infinity;
	            	_minV = Infinity;
	            	_maxV = -Infinity;
	            	_index = _faceVO.uvs.length;
	            	
	            	while (_index--) {
	            		_uv = _faceVO.uvs[_index];
		            	//calculate bounding box
		            	_u = _uv._u;
		            	_v = _uv._v;
	            		if (_minU > _u)
	            			_minU = _u;
	            		if (_maxU < _u)
	            			_maxU = _u;
	            		if (_minV > _v)
	            			_minV = _v;
	            		if (_maxV < _v)
	            			_maxV = _v;
	            	}
            	
	        		//update face bitmapRect
	        		_faceVO.face.bitmapRect = new Rectangle(_faceX = int(_width*_minU), _faceY = int(_height*(1 - _maxV)), _faceWidth = int(_width*(_maxU-_minU)+2), _faceHeight = int(_height*(_maxV-_minV)+2));
	        		
	        		//update texturemapping
	        		_faceMaterialVO.invtexturemapping = transformUV(_faceVO).clone();
	        		_faceMaterialVO.texturemapping = _faceMaterialVO.invtexturemapping.clone();
	        		_faceMaterialVO.texturemapping.invert();
	        		//resize bitmapData for container
	        		_faceMaterialVO.resize(_faceWidth, _faceHeight, transparent);
	        	}
        		
        		_fMaterialVO = _faceMaterialVO;
        		
	    		//call renderFace on each material
	    		for each (var _material:LayerMaterial in materials)
	        		_fMaterialVO = _material.renderBitmapLayer(priIndex, viewSourceObject, renderer, _bitmapRect, _fMaterialVO);
        		
        		_cacheDictionary[_faceVO] = _fMaterialVO.bitmap;
	        	
	        	_fMaterialVO.updated = false;
			}
        	
        	_renderBitmap = _cacheDictionary[_faceVO];
        	
        	//check to see if tri is generated
        	if (_generated) {
        		_bRect = _faceVO.face.bitmapRect;
        		_faceX = _bRect.x;
        		_faceY = _bRect.y;
        		_faceWidth = _bRect.width;
        		_faceHeight = _bRect.height;
        		
        		//update texturemapping
        		_texturemapping = transformUV(_faceVO).clone();
				_texturemapping.invert();
	    		
	    		return _texturemapping;
        	}
			
    		return _faceMaterialVO.texturemapping;
        }
		
		/**
		 * Defines whether the caching bitmapData objects are transparent
		 */
		public var transparent:Boolean;
		
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
			_surfaceCache = ini.getBoolean("surfaceCache", false);
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