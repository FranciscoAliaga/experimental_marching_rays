vec2 pixel_uv(vec2 uv, ivec2 pixels){
	vec2 ans;
	ans.x = floor(uv.x * float(pixels.x-1) + 0.5)/float(pixels.x-1);
	ans.y = floor(uv.y * float(pixels.y-1) + 0.5)/float(pixels.y-1);
	return ans;
}

bool far_away(vec3 pos,float faraway){
	return length(pos) > faraway;
}

// thanks to inigo quilez implementation
float exp_smin( float a, float b, float k )
{
    float res = exp2( -k*a ) + exp2( -k*b );
    return -log2( res )/k;
}

// thanks to inigo quilez implementation
float smin(float a,float b){
	return exp_smin(a,b,2.);
}


vec3 reflect_vector_plane(vec3 rd, vec3 normal){
	vec3 n = normalize(normal);
	return normalize(rd - 2.*dot(rd,n)*n);
}

float sphere_sdf(vec3 pos, vec3 center, float radius){
	return length((pos-center)) - radius;
}

// thanks to inigo quilez implementation
float cube_sdf(vec3 pos, vec3 center, vec3 R){
	float d = length(max(abs(pos-center)-R,vec3(0.)));
	return d;
}

// structures for the ray marching algorithm
struct ray_march_hit {
	vec3 position;
	vec4 color;
	float depth;
	bool max_iterations;
	float sdf;
};

struct color_and_depth {
	vec4 color;
	float depth;
};

