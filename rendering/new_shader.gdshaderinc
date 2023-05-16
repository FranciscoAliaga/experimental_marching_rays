vec2 pixel_uv(vec2 uv, ivec2 pixels){
	
	vec2 ans;
	ans.x = floor(uv.x * float(pixels.x-1) + 0.5)/float(pixels.x-1);
	ans.y = floor(uv.y * float(pixels.y-1) + 0.5)/float(pixels.y-1);
	return ans;
}

bool far_away(vec3 pos,float faraway){
	return length(pos) > faraway;
}

float exp_smin( float a, float b, float k )
{
    float res = exp2( -k*a ) + exp2( -k*b );
    return -log2( res )/k;
}

float smin(float a,float b){
	if (abs(a-b)<0.1){
		return min(a,b);
	}
	return exp_smin(a,b,2.);
}

float random (vec2 uv) {
    return fract(sin(dot(uv.xy,
        vec2(12.9898,78.233))) * 43758.5453123);
}

vec3 reflect_vector_plane(vec3 rd, vec3 normal){
	vec3 n = normalize(normal + 0.2*vec3(random(normal.xy)));
	return normalize(rd - 2.*dot(rd,n)*n);
}

float sphere_sdf(vec3 pos, vec3 center, float radius){
	return length((pos-center)) - radius;
}

float weird_sphere_sdf(vec3 pos, vec3 center, float radius,float t){
	return length((pos-center)-vec3(cos(5.*t+0.3*pos.y),cos(t-0.2*pos.x),-1.)) - radius;
}

float cube_sdf(vec3 pos, vec3 center, vec3 R){
	float d = length(max(abs(pos-center)-R,vec3(0.)));
	return d;
}