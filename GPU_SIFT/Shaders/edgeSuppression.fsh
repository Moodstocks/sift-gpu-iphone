//fragment shader
//removes edge responses and low contrast keypoints

uniform mediump vec2 readingPosition;
uniform mediump sampler2D pic0;
uniform mediump sampler2D pic1;
uniform mediump float width;
uniform mediump float height;
uniform mediump int scale;

void main(void)
{	
	mediump float offseth = 1.0/width;
	mediump float offsetv = 1.0/height;
	
	mediump float thresEdge=10.0;
	
	mediump vec4 t[9];
	t[0]=vec4(texture2D(pic0, readingPosition+vec2(-0.5*offseth,-0.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(-0.5*offseth,-0.5*offsetv)).xy);
	t[1]=vec4(texture2D(pic0, readingPosition+vec2(-0.5*offseth,0.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(-0.5*offseth,0.5*offsetv)).xy);
	t[2]=vec4(texture2D(pic0, readingPosition+vec2(-0.5*offseth,1.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(-0.5*offseth,1.5*offsetv)).xy);
	t[3]=vec4(texture2D(pic0, readingPosition+vec2(0.5*offseth,-0.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(0.5*offseth,-0.5*offsetv)).xy);
	t[4]=vec4(texture2D(pic0, readingPosition+vec2(0.5*offseth,0.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(0.5*offseth,0.5*offsetv)).xy);
	t[5]=vec4(texture2D(pic0, readingPosition+vec2(0.5*offseth,1.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(0.5*offseth,1.5*offsetv)).xy);
	t[6]=vec4(texture2D(pic0, readingPosition+vec2(1.5*offseth,-0.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(1.5*offseth,-0.5*offsetv)).xy);
	t[7]=vec4(texture2D(pic0, readingPosition+vec2(1.5*offseth,0.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(1.5*offseth,0.5*offsetv)).xy);
	t[8]=vec4(texture2D(pic0, readingPosition+vec2(1.5*offseth,1.5*offsetv)).yz, texture2D(pic1, readingPosition+vec2(1.5*offseth,1.5*offsetv)).xy);
	
	//multiplicative factors are added to normalize, according to VLfeat
	
	mediump float Dxx = (t[7]+t[1]-2.0*t[4])[scale];
	mediump float Dyy = (t[5]+t[3]-2.0*t[4])[scale];
	
	mediump float Dxy = 0.25*(t[8]+t[0]-t[2]-t[6])[scale];
	
	//Edge Thresholding
	if ((Dxx+Dyy)*(Dxx+Dyy)/(Dxx*Dyy-Dxy*Dxy)>(thresEdge+1.0)*(thresEdge+1.0)/thresEdge) {
		gl_FragColor = vec4(1.0);
	}
	else {
		gl_FragColor = vec4(0.0);
	}

}

	
	
	
	
	