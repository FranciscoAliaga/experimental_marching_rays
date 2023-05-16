shader_type canvas_item;

#include "./new_shader.gdshaderinc"

// x horizontal
// y vertical
// z forward

uniform vec3 camera_pos;
uniform mat3 camera_rotation;

uniform int x_pixels;
uniform int y_pixels;

uniform float max_reflection : hint_range(0.,1.);

uniform vec4 floor_color : source_color;
uniform vec4 sky_color : source_color;
uniform vec4 fog_color : source_color;
uniform float foggyness : hint_range(0.,1.);
uniform float fog_decay : hint_range(1.,100.);

const float dh   = 0.01;
const float idh  = 1./dh;

const float near = 0.01;
const float far  = 100.;

#define RAY_JUMPS 3
#define JUMP_SEARCH 20
#define JUMP_MULT 20.

#define MAX_STEPS 20


// takes an uv coordinate from the screen renderer and
// returns the normalized ray.
vec3 ray(vec2 uv){
	// center uv
	vec2 uuvv = uv - vec2(0.5,0.5);
	// invert y coordinate
	uuvv.y *= -1.;
	// pass a ray through the {(x,y,z) : z=1} plane coming from the origin
	vec3 rd = vec3(uuvv,1.);
	// transform it according to camera
	rd = camera_rotation * rd;
	// return answer
	return normalize(rd);
}

float get_sdf2(vec3 pos, float t){
	vec3 center = vec3(0.,-2.,5.);
	
	float RR = 0.8;
	float ans = 100.;
	
	int N = 10;
	float r = 3.;
	for(int i = 0; i <N ; i++ ){
		float angle = 2.*PI*float(i)/float(N);
		vec3 c_center = center + vec3(0.,0.,0.);
		vec3 displacement = r*vec3(cos(angle+t),0.,sin(angle+t));
		if (i%2==0){
			ans = min(ans,sphere_sdf(pos,c_center+displacement,RR));
		}
		else{
			ans = min(ans,cube_sdf(pos,c_center+displacement,vec3(RR)));
		}
		
	}
	
	return ans;
}

float get_sdf(vec3 pos, float t){
	float real = get_sdf2(pos,t);
	float imag = get_sdf2(mod(abs(pos),vec3(5.,5.,5.)),t);
	return min(real,imag);
}



vec3 get_gradient(vec3 pos,float t){
	float dx = get_sdf(pos+vec3(dh,0.,0.),t) - get_sdf(pos,t) ;
	float dy = get_sdf(pos+vec3(0.,dh,0.),t) - get_sdf(pos,t) ;
	float dz = get_sdf(pos+vec3(0.,0.,dh),t) - get_sdf(pos,t) ;
	return vec3(dx,dy,dz)*idh;
}


vec4 get_color(vec3 pos,float depth, float t){
	if (depth >= far){
		if (pos.y > 0.) return sky_color;
		else return floor_color;
	}
	if (get_sdf(pos,t)<=1.5*near){
		return vec4(vec3(0.),1.);
	}
	return vec4(vec3(0.),1.);
}

struct ray_march_hit {
	vec3 position;
	vec4 color;
	float depth;
};

struct color_and_depth {
	vec4 color;
	float depth;
};

ray_march_hit ray_march(vec3 pos, vec3 ray, float t, bool first_ray){
	ray_march_hit result;
	result.depth = 0.;
	
	bool break_condition = false;
	int steps = 0;
	float d;
	
	if(first_ray){
		d = get_sdf(pos,t);
	} else { // find largest d such that gradient is increasing with ray.
		d = near;
		for(int j = 0; j<JUMP_SEARCH;j++){
			vec3 gradient = get_gradient(pos+d*ray ,t);
			bool getting_away = dot(ray,normalize(gradient)) > 0.;
			if (!getting_away){
				d /= JUMP_MULT;
				break;
			}
			d*= JUMP_MULT;
		}
	}
	
	do {
		result.depth += d;
		pos = pos + ray * d;
		d = get_sdf(pos,t);
		steps++;
		break_condition = (d <= 0.);
	} while ( (!break_condition) && (steps < MAX_STEPS  ));
	
	result.position = pos;
	result.color  = get_color(pos,result.depth,t);
	return result;
}

color_and_depth ray_marching(vec3 pos, vec3 ray, float t){
	color_and_depth result;
	ray_march_hit[RAY_JUMPS] hits;
	
	for(int i = 0; i < RAY_JUMPS; i++){
		hits[i] = ray_march(pos,ray,t,(i==0));
		pos = hits[i].position;
		if(length(pos) >= far) continue;
		ray = reflect_vector_plane(ray,get_gradient(pos,t));
	}
	vec4 color = hits[0].color;
	for(int i = 1; i < RAY_JUMPS; i++){
		color = (1.-max_reflection) * color + max_reflection * hits[i].color;
	}
	
	result.color = color;
	result.depth = hits[0].depth;
	return result;
}

void fragment() {
	// first ray march
	vec3 ro = camera_pos;
//	vec3 rd = ray(UV);
	 vec3 rd = ray(pixel_uv(UV,ivec2(x_pixels,y_pixels)));
	
	color_and_depth result = ray_marching(ro,rd,TIME);
	
	// color calculation
	vec4 color = result.color;
	
	float ff = foggyness * min(1.,result.depth/fog_decay);
	color = (1.-ff) * color + ff * fog_color;
	
	COLOR = color;
	COLOR.a = 1.;
	//COLOR.rgb = vec3(result.depth/100.);
	
}

