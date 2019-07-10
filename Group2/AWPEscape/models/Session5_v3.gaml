/***
* Name: AWPEscape
* Author: AWP
* Description: Step 0 of the AWP training evacuation model 
* Tags: evacuation and flood
***/
model CityEscape

global {
	
	file road_file <- file("../includes/road_environment.shp");
	file buildings <- file("../includes/building_environment.shp");
	file evac_points <- file("../includes/evacuation_environment.shp");
	file water_body <- file("../includes/sea_environment.shp");
	
	geometry shape <- envelope(envelope(road_file)+envelope(water_body));
	
	graph<geometry, geometry> road_network;
	map<road,float> road_weights;
	
	float step <- 10#s;

	int nb_of_people <- 1000;
	float min_perception_distance <- 25.0;
	float max_perception_distance <- 50.0;
	
	float time_before_hazard <- 10#mn;
	string the_alert_strategy;
	int nb_stages <- 8;
	
	int casualties;

	init {
		create road from:road_file;
		create building from:buildings;
		
		create hazard from:water_body;
		create evacuation_point from:evac_points;
		
		create inhabitant number:nb_of_people {
			location <- any_location_in(one_of(building));
		}
		
		create crisis_manager;
		
		road_network <- as_edge_graph(road);
		road_weights <- road as_map (each::each.shape.perimeter);
	}
	
	reflex stop_simu when:empty(inhabitant){
		do pause;
	}
		
}

species crisis_manager {
	
	float alert_range;
	float time_after_last_stage <- 5#mn;

	int nb_per_stage;

	geometry buffer;
	float distance_buffer;

	init {
		alert_range <- (time_before_hazard - time_after_last_stage) / nb_stages;
		
		int modulo_stage <- length(inhabitant) mod nb_stages; 
		nb_per_stage <- int(length(inhabitant) / nb_stages) + (modulo_stage = 0 ? 0 : 1);
		
		buffer <- line({0,world.shape.height},{world.shape.width,world.shape.height});
		distance_buffer <- world.shape.height / nb_stages;
	}
	
	
	reflex send_alert when: alert_conditional() {
		ask alert_target() { self.alerted <- true; }
	}
	
	bool alert_conditional {
		if(the_alert_strategy = "STAGED" or the_alert_strategy = "SPATIAL"){
			return cycle = 0 or every(alert_range);
		} else {
			if(cycle = 0){
				return true;
			} else {
				return false;
			}
		}
	}
	
	list<inhabitant> alert_target {
		switch the_alert_strategy {
		match "STAGED" {
			return nb_per_stage among (inhabitant where (each.alerted = false));
		}
		match "SPATIAL" {
			buffer <- buffer buffer distance_buffer;
			return inhabitant overlapping buffer;
		}
		default {
			return list(inhabitant);
		}
	}
	}
	
}

species hazard {
	
	float speed <- 0.2#km/#h;
	
	date catastrophe_date;

	init {
		catastrophe_date <- current_date + time_before_hazard;
	}
	 
	reflex expand when:catastrophe_date < current_date {
		shape <- shape buffer (speed * step);
		ask inhabitant overlapping self {
			casualties <- casualties + 1; 
			do die;
		}
	}
	
	aspect default {
		draw shape color:#blue;
	}
	
}

species inhabitant skills:[moving] {

	evacuation_point safety_point <- evacuation_point closest_to self;

	float perception_dist <- rnd(min_perception_distance, max_perception_distance);
	bool alerted <- false;

	reflex perceive_hazard when: not alerted {
		alerted <- not empty (hazard at_distance perception_dist);
	}
	
	reflex evacuate when: alerted {
		do goto target:safety_point on:road_network;
		if(location distance_to safety_point.location < 2#m){ 
			ask safety_point {do evacue_inhabitant;}
			do die;
		}
		if(current_edge != nil){
			road the_current_road <- road(current_edge);  
			the_current_road.users <- the_current_road.users + 1;
		} 
	}
	
	aspect default {
		draw circle(1#m) color: alerted ? #red : #blue;
	}

}

species road {
		
	int users;
	// TODO : turn 8 as a parameter
	int capacity <- int(shape.perimeter*4); 

	float speed_coeff <- 1;
	
	reflex update_weights {
		speed_coeff <- max(0.05,exp(-users/capacity));
		road_weights[self] <- shape.perimeter / speed_coeff;
		users <- 0;
	}
	
	aspect default {
		draw shape width: 4#m-(3*speed_coeff)#m color:rgb(55+200*length(users)/shape.perimeter,0,0);	
	}
}

species building {
	aspect default {
		draw shape color: #gray border: #black;
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
	
	parameter "Alert Strategy" var:the_alert_strategy init:"DEFAULT" among:["STAGED","SPATIAL","DEFAULT"];
	
	output {
		display my_display type: opengl { 
			species hazard;
			species road;
			species inhabitant;
			species building;
			species evacuation_point;
		}
		monitor number_of_casualties value:casualties;
	}
	
}

