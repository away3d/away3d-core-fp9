package away3d.materials
{
    import away3d.arcane;
    import away3d.core.draw.*;
    import away3d.core.utils.*;
    
    import flash.display.*;
    import flash.geom.*;
    
	use namespace arcane;
	
    /**
    * Basic material for layering
    */
    public class LayerMaterial extends ColorMaterial
    {
    	/** @private */
        arcane function renderLayer(tri:DrawTriangle, layer:Sprite, level:int):int
        {
        	throw new Error("Not implemented");
        }
    	/** @private */
        arcane function renderBitmapLayer(tri:DrawTriangle, containerRect:Rectangle, parentFaceMaterialVO:FaceMaterialVO):FaceMaterialVO
		{
			throw new Error("Not implemented");
    	}
		
		/**
		 * Returns the width of the <code>LayerMaterial</code>.
		 */
		public function get width():Number
		{
			return 0;
		}
		
		/**
		 * Returns the height of the <code>LayerMaterial</code>.
		 */
		public function get height():Number
		{
			return 0;
		}
		
		/**
		 * Creates a new <code>LayerMaterial</code> object.
		 * 
		 * @param	init	[optional]	An initialisation object for specifying default instance properties.
		 */
        public function LayerMaterial(init:Object = null)
        {
        	ini = Init.parse(init);
        	
            super(ini.getColor("color", 0xFFFFFF), ini);
        }
	}
}
