/***
* Name: CityEscape
* Author: kevinchapuis
* Description: An evacuation model of a theoretical city with different alert communication strategies. Hazard is a very simple flood
* and we make the hypothesis that people die when they are in the flood (e.g. Tsunami). The flooding start x time after the beginning
* of the simulation. People escape when they perceive the flood or when they are alerted. There are 3 communication strategies: 
* - 'EVERYONE' = to alert everyone at the start of the simulation
* - 'STAGED' = to alert nb_people/nb_stages random people every (time_of_hazard-buffer_time)/nb_stages minutes
* - 'SPATIAL' = to alert nb_people/nb_stages closest people to exits every (time_of_hazard-buffer_time)/nb_stages minutes
* Where (time_of_hazard-buffer_time)/nb_stages correspond to the time between stages computed using the three parameters:
* - Time before hazard = time_of_hazard
* - Time alert buffer before hazard = buffer_time
* - Number of stages = nb_stages
* Tags: evacuation, traffic, hazard, gis, water
***/
model CityEscape

global {

// Starting date of the simulation
	date starting_date <- #now;

	// Time step to represent very short term movement (for congestion)
	float step <- 10 #sec;
	int nb_of_people;

	// To initialize perception distance of inhabitant
	float min_perception_distance <- 10.0;
	float max_perception_distance <- 30.0;
	//to alert the others
	float alert_distance <- 5.0 #m;

	// to decide if helping or not
	float patients_distance <- 10.0 #m;

	// Represents the capacity of a road indicated as: number of inhabitant per #m of road
	float road_density;

	// Parameters of the strategy
	int time_after_last_stage;
	string the_alert_strategy;
	int nb_stages;

	// Parameters of hazard
	int time_before_hazard;
	float flood_front_speed;
	file road_file <- file("../includes/road_environment.shp");
	file buildings <- file("../includes/building_environment.shp");
	map<int, rgb> colors <- [0::#green, 1::#yellow, 2::#blue];
	image_file fire <- image_file("../images/fire1.gif");
	geometry shape <- envelope(road_file);

	// Graph road
	graph<geometry, geometry> road_network;
	map<road, float> road_weights;

	// Output the number of casualties
	int casualties;
	//	geometry bound_of_building;
	init {
		create road from: road_file;
		create building from: buildings with: [type:: string(get("TYPE"))];
		//		bound_of_building <- convex_hull(union(building where (each.type != "rescue")));
		//		create evacuation_point from:evac_points;
		//		create hazard from: water_body;
		create hazard {
			location <- any_location_in(any(building where (each.type = "floor3")));
		}

		create inhabitant number: nb_of_people {
			location <- any_location_in(one_of(building where (each.type != "rescue")));
			safety_point <- any(building where (each.type = "rescue"));
			perception_distance <- rnd(min_perception_distance, max_perception_distance);
		}

		ask (0.3 * nb_of_people) among inhabitant {
			type <- 1;
			speed <- 0.1 #km / #h;
		}

		ask (0.5 * length(inhabitant where (each.type = 1))) among (inhabitant where (each.type = 1)) {
			type <- 2;
		}

		//		create crisis_manager;
		road_network <- as_edge_graph(road);
		road_weights <- road as_map (each::each.shape.perimeter);
		ask ground {
			if (length(building overlapping self) = 0 and length(road overlapping self) = 0) {
				do die;
			}

		}

	}

	// Stop the simulation when everyone is either saved :) or dead :(
	reflex stop_simu when: inhabitant all_match (each.saved or each.burnt) {
		do pause;
	}

}

/*
 * Agent responsible of the communication strategy
 */
species crisis_manager {

/*
	 * Time between each alert stage (#s)
	 */
	float alert_range;

	/*
	 * The number of people to alert every stage
	 */
	int nb_per_stage;

	/*
	 * Parameter to compute spatial area of each stage in the SPATIAL strategy
	 */
//	geometry buffer;
	float distance_buffer;

	init {
	// For stage strategy
		int modulo_stage <- length(inhabitant) mod nb_stages;
		nb_per_stage <- int(length(inhabitant) / nb_stages) + (modulo_stage = 0 ? 0 : 1);

		// For spatial strategy
		//		buffer <- geometry(evacuation_point collect (each.shape buffer 1 #m));
		distance_buffer <- world.shape.height / nb_stages;
		alert_range <- (time_before_hazard #mn - time_after_last_stage #mn) / nb_stages;
	}

	/*
	 * If the crisis manager should send an alert
	 */
	reflex send_alert when: alert_conditional() {
	//		ask alert_target() {
	//			self.alerted <- true;
	//		}

	}

	/*
	 * The conditions to send an alert : return true at cycle = 0 and then every(alert_range)
	 * depending on the strategy used
	 */
	bool alert_conditional {
		if (the_alert_strategy = "STAGED" or the_alert_strategy = "SPATIAL") {
			return every(alert_range);
		} else {
			if (cycle = 0) {
				return true;
			} else {
				return false;
			}

		}

	}

	/*
	 * Who to send the alert to: return a list of inhabitant according to the strategy used
	 */
	list<inhabitant> alert_target {
		switch the_alert_strategy {
			match "STAGED" {
				return nb_per_stage among (inhabitant where (each.alerted = false));
			}

			//			match "SPATIAL" {
			//				buffer <- buffer buffer distance_buffer;
			//				return inhabitant overlapping buffer;
			//			}
			match "EVERYONE" {
				return list(inhabitant);
			}

			default {
				return [];
			}

		}

	}

}

/*
 * Represent the water body. When attribute triggered is turn to true, inhabitant
 * start to see water as a potential danger, and try to escape
 */
species hazard {
	float size <- 1.0;
	// The date of the hazard
	date catastrophe_date;
	point loc;
	// Is it a tsunami ? (or just a little regular wave)
	bool triggered;

	init {
		catastrophe_date <- current_date + time_before_hazard #mn;
	}

	reflex fire {
		ask (ground overlapping self) {
			temperature <- 1000.0;
		}

	}

	aspect default {
		draw square(1) color: #red;
	}

}

/*
 * Represent the inhabitant of the area. They move at foot. They can pereive the hazard or be alerted
 * and then will try to reach the one randomly choose exit point
 */
species inhabitant skills: [moving] {
	int type <- 0; //0: normal 1: patient 2:critical_patient 

	// The state of the agent
	bool alerted <- false;
	bool burnt <- false;
	bool saved <- false;
	bool is_helped <- false;

	// How far (#m) they can perceive
	float perception_distance;

	// The exit point they choose to reach
	building safety_point;
	// How fast inhabitant can run
	float speed <- 3 #km / #h;
	inhabitant my_critical_patients;
	bool has_reach_my_critical_patient <- false;

	/*
	 * Am I burning ?
	 */
	reflex burnt when: not (burnt or saved) {
		if (!dead((ground closest_to self)) and (ground closest_to self).burning) {
			burnt <- true;
			casualties <- casualties + 1;
		}
		if (my_critical_patients!=nil and !my_critical_patients.saved and !my_critical_patients.burnt) {
			my_critical_patients.is_helped<-false;
		}

	}
	/*
	 * Is there any danger around ?
	 */
	reflex perceive when: not (alerted or burnt) {
	//		ground g<-(ground where (!(dead(each)))where (each.burning)) closest_to self;
	//		write (ground at_distance perception_distance) where (!dead(each) and each.burning);
	//		if(g!=nil){				
	//			if self.location distance_to g < perception_distance {
		if (length((ground at_distance perception_distance) where (!dead(each) and each.burning)) > 0) {
			alerted <- true;
		}
		//		}
		//list of patients that needs to be helped near to the normal people

	}

	reflex spreading_alert when: alerted and not (burnt or saved) {
		list<inhabitant> neighbors <- inhabitant at_distance alert_distance;
		ask neighbors {
			alerted <- true;
		}

	}

	reflex go_to_save_patient when: type = 0 and my_critical_patients != nil and !has_reach_my_critical_patient {
		if (my_critical_patients.burnt) {
			my_critical_patients <- nil;
			has_reach_my_critical_patient <- true;
		}

		do goto target: my_critical_patients on: road_network move_weights: road_weights;
		if (my_critical_patients != nil) and (location distance_to my_critical_patients < 0.5 #m) {
			has_reach_my_critical_patient <- true;
			saved <- false;
		}

	}
	/*
	 * When alerted people will try to go to the choosen exit point
	 */
	reflex evacuate when: alerted and not (burnt or saved) and type != 2 {
		if (type = 0 and my_critical_patients = nil) {
			has_reach_my_critical_patient <- false;
			my_critical_patients <- any((inhabitant at_distance patients_distance) where (each.type = 2 and !each.is_helped));
			my_critical_patients.is_helped <- true;
		}

		if (my_critical_patients != nil) {
			if (!has_reach_my_critical_patient) {
				return;
			}

			if (!(my_critical_patients.burnt)) {
				my_critical_patients.location <- location;
			} else {
				my_critical_patients <- nil;
			}

		}

		do goto target: safety_point on: road_network move_weights: road_weights;
		if (current_edge != nil) {
			road the_current_road <- road(current_edge);
			if (!dead(the_current_road)) {
				the_current_road.users <- the_current_road.users + 1;
				if (my_critical_patients != nil and !(my_critical_patients.burnt)) {
					the_current_road.users <- the_current_road.users + 1;
				}

			}

		}

	}

	reflex go_back when: saved and type = 0 {
		list lst_patient <- (inhabitant where (!each.burnt and !each.saved and each.type != 0 and !each.is_helped));
		if(length(lst_patient) > 0){			
			if (my_critical_patients = nil) {
				alerted <- true;
				has_reach_my_critical_patient <- false;
				my_critical_patients <- lst_patient closest_to self;
				if (my_critical_patients != nil) {
					my_critical_patients.is_helped <- true;
				} else{
					saved<-false;
				}
	
			} 
			else {
				saved <- false;
				alerted <- true;
			}
		}
		//		if (has_reach_my_critical_patient) {
		//			my_critical_patients.location <- location;
		//			do goto target: safety_point on: road_network move_weights: road_weights;
		//		} else {
		//			do goto target: my_critical_patients on: road_network move_weights: road_weights;
		//		}
		//
		//		if (location distance_to my_critical_patients < 1 #m) {
		//			has_reach_my_critical_patient <- true;
		//		}

	}

	/*
	 * Am I safe ?
	 */
	reflex escape when: not (saved) and location distance_to safety_point < 2 #m {
		saved <- true;
		location <- any_location_in(safety_point);
		alerted <- false;
		if (my_critical_patients != nil) {
			my_critical_patients.alerted <- false;
			my_critical_patients.saved <- true;
			my_critical_patients.location <- any_location_in(safety_point);
			my_critical_patients <- nil;
		}

	}

	aspect default {
		draw burnt ? cross(2, 0.5) : (alerted ? circle(1 #m) : square(1 #m)) color: burnt ? #black : colors[type];
		//		draw "" + type at: location font: font("Helvetica", 6, #bold);
	}

}

/*
 * The roads inhabitant will use to evacuate. Roads compute the congestion of road segment
 * accordin to the Underwood function.
 */
species road {

// Number of user on the road section
	int users;
	// The capacity of the road section
	int capacity <- int(shape.perimeter * road_density);
	// The Underwood coefficient of congestion
	float speed_coeff <- 1.0;

	// Update weights on road to compute shortest path and impact inhabitant movement
	reflex update_weights {
		speed_coeff <- max(0.05, exp(-users / capacity));
		road_weights[self] <- shape.perimeter / speed_coeff;
		users <- 0;
	}

	// Cut the road when flooded so people cannot use it anymore
	reflex flood_road {
		if (hazard first_with (each covers self) != nil) {
			road_network >- self;
			do die;
		}

	}

	aspect default {
		draw shape width: 1 #m - (3 * speed_coeff) #m color: rgb(55 + 200 * users / capacity, 0, 0);
	}

}

/*
 * People are located in building at the start of the simulation
 */
species building {
	string type;

	aspect default {
		draw shape color: #gray border: #black;
	}

}

grid ground width: 100 height: 100 neighbors: 4 {
	bool burning <- false;
	float temperature <- 20.0;

	reflex fire_spreading {
		float avg_temp <- mean(((neighbors + self) where (!dead(each))) accumulate (each.temperature));
		temperature <- avg_temp;
		if (temperature > 100) {
			burning <- true;
		}

		ask neighbors {
			temperature <- avg_temp;
		}

	}

	aspect default {
		if (burning) {
			draw shape color: #red;
		} else {
		}

	}

}

experiment my_experiment {
	float minimum_cycle_duration <- 0.1;
	parameter "Alert Strategy" var: the_alert_strategy init: "NONE" among: ["NONE", "STAGED", "SPATIAL", "EVERYONE"] category: "Alert";
	parameter "Number of stages" var: nb_stages init: 6 category: "Alert";
	parameter "Time alert buffer before hazard" var: time_after_last_stage init: 5 unit: #mn category: "Alert";
	parameter "Road density index" var: road_density init: 6.0 min: 0.1 max: 10.0 category: "Congestion";
	parameter "Speed of the flood front" var: flood_front_speed init: 5.0 min: 1.0 max: 30.0 unit: #m / #mn category: "Hazard";
	parameter "Time before hazard" var: time_before_hazard init: 5 min: 0 max: 10 unit: #mn category: "Hazard";
	parameter "Number of people" var: nb_of_people init: 500 min: 100 max: 20000 category: "Initialization";
	output {
		display my_display type: opengl background: #lightgray {
			graphics legend {
				draw "3rd floor" color: #black font: font("SansSerif", 20, #bold) at: {100 #px, 40 #px} perspective: false;
				draw "2nd floor" color: #black font: font("SansSerif", 20, #bold) at: {100 #px, 280 #px} perspective: false;
				draw "1st floor" color: #black font: font("SansSerif", 20, #bold) at: {100 #px, 520 #px} perspective: false;
				draw "Rescue schelter" color: #black font: font("SansSerif", 20, #bold) at: {20 #px, 700 #px} perspective: false;
			}

			species road;
			species building;
			species inhabitant;
			species hazard position: {0, 0, 0.003};
			species ground position: {0, 0, 0.002} transparency: 0.25;
		}

		//		monitor "Number of casualties" value: casualties;
	}

}



