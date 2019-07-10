/***
* Name: AWPEscape
* Author: AWP
* Description: Step 0 of the AWP training evacuation model 
* Tags: evacuation and flood
***/
model CityEscape

global {
	
	geometry shape <- 500#m;
	
	float step <- 10#s;
	
	int nb_of_people <- 1000;
	float min_perception_distance <- 50.0;
	float max_perception_distance <- 500.0;
	

	init {
		create hazard;
		create evacuation_point with:[location::{0,0}];
		create inhabitant number:nb_of_people;
	}
		
}

species hazard {
	
	float speed <- 0.2#km/#h;
	
	geometry shape <- circle(20#m);
	 
	reflex expand {
		shape <- shape buffer (speed * step);
	} 
	
}

species inhabitant skills:[moving] {

	evacuation_point safety_point <- any(evacuation_point);

	float perception_dist <- rnd(min_perception_distance, max_perception_distance);
	bool alerted <- false;

	reflex perceive_hazard when: not alerted {
		alerted <- not empty (hazard at_distance perception_dist);
	}
	
	reflex evacuate when: alerted {
		do goto target:safety_point;
	}
		
	aspect default {
		draw circle(1#m) color: alerted ? #red :#blue;
	}

}

species evacuation_point {
	
	int count_exit <- 0;
	
	action evacue_inhabitant {
		count_exit <- count_exit + 1;
	}

	aspect default {
		draw circle(1#m+19#m*count_exit/nb_of_people) color:#green;
	}
	
}

experiment my_experiment {
	output {
		display my_display type: opengl { 
			species hazard;
			species inhabitant;
		}
	}
}

