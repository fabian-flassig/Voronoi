-- a 2D Voronoi creation following Fortunes Algorithm. Credits to Jon Michael Aanes for the algorithm. 
-- Check out https://bitbucket.org/Jmaa/luafortune for documentation.



------ Configuration --------
local data = {length = 1000,
				width = 600,
				number_points = 100,
				min_distance = 50,
				segments = -36,
				show_points = false,
				name = pyloc "Voronoi",
				noise = 1,
			}
-----------------------------

local point_list = {}

function main()

	local loaded_data = pyio.load_values("default_dimensions")
	if loaded_data ~= nil then 
		for k,v in pairs(loaded_data) do data[k] = v end
	end
	
	pyui.run_modal_dialog(init_dlg, data)
	pyio.save_values("default_dimensions", data)

end

function init_dlg(dialog, data)
	local controls = {}
	dialog:set_window_title(pyloc "Voronoi Creator")

	local label_name = dialog:create_label(1, pyloc "Name")
	local name = dialog:create_text_box(2, data.name)
	local show_points = dialog:create_check_box({3,4}, pyloc "Show points")
	show_points:set_control_checked(data.show_points)

	dialog:create_align({1,4})

	local label_length = dialog:create_label(1, pyloc "Length")
	local length = dialog:create_text_box(2, pyui.format_length(data.length))
	local label_width = dialog:create_label(3, pyloc "Width")
	local width = dialog:create_text_box(4, pyui.format_length(data.width))
	
	dialog:create_align({1,4})

	local label_noise = dialog:create_label(1, pyloc "Noise type")
	local noise = dialog:create_drop_list(2)
	noise:insert_control_item(pyloc "White")
	noise:insert_control_item(pyloc "Blue")
	noise:set_control_selection(data.noise)
	controls.label_points = dialog:create_label(3, pyloc "Number of points")
	controls.points = dialog:create_text_spin(4, data.number_points)

	dialog:create_align({1,4})

	local ok = dialog:create_ok_button(3)
    local cancel = dialog:create_cancel_button(4)
	dialog:equalize_column_widths({1, 2, 3, 4})
	
	name:set_on_change_handler(function(text)
        data.name = text or data.name
		recreate_geometry(data)
    end)
	length:set_on_change_handler(function(text)
        data.length = pyui.parse_length(text) or data.length
		if data.length > 0 then
			recreate_geometry(data)
		end
    end)
	
	width:set_on_change_handler(function(text)
        data.width = pyui.parse_length(text) or data.width
		if data.width > 0 then
			recreate_geometry(data)
		end
    end)

	show_points:set_on_click_handler(function(state)
		data.show_points = state
		recreate_no_new_points(data, point_list)
	end)
	
	noise:set_on_change_handler(function(text, new_index)
		data.noise = new_index
		update_ui(data, controls)
		recreate_geometry(data)
	end)
	update_ui(data, controls)
	recreate_geometry(data)
end

function update_ui(data, controls)
	if data.noise == 1 then 
		controls.label_points:set_control_text(pyloc "Number of points")
		controls.points:set_control_text(pyui.format_number(data.number_points))
		controls.points:set_control_range(20,1000)
		controls.points:set_on_change_handler(function(text)
			data.number_points = math.min(1000, math.max(20,math.tointeger(pyui.parse_number(text) or data.number_points)))
			if data.number_points > 0 then
				recreate_geometry(data)
			end
		end)
	else 
		controls.label_points:set_control_text(pyloc "Min distance")
		controls.points:set_control_text(pyui.format_length(data.min_distance))
		local min = math.ceil(math.sqrt(data.length * data.width / 1000))
		local max = math.floor(math.sqrt(data.length * data.width / 20))
		controls.points:set_control_range(min, max)
		controls.points:set_on_change_handler(function(text)
			data.min_distance = math.min(max, math.max(min, pyui.parse_length(text) or data.min_distance))
			if data.min_distance > 0 then
				recreate_geometry(data)
			end
		end)
	end
end

function recreate_geometry(data)
	point_list = recreate_points(data)
	
	recreate_no_new_points(data, point_list)
end

function recreate_no_new_points(data, points)

	local elements = {}
	if data.main_group ~= nil then
		pytha.delete_element(data.main_group)
	end
	elements = voronoi_geometry(data, points)

	data.main_group = pytha.create_group(elements, {name = data.name})

end

function area_orientation(face)
	local area = 0
	for i=1, #face, 1 do
		area = area + 0.5 * (face[i].x * face[i%#face+1].y - face[i%#face+1].x * face[i].y)
	end
	return area > 0 and 1 or (math.abs(area) < 1e-7 and 0 or -1)
end

function voronoi_geometry(data, points)
	local elements = {}
	local edges = {}
	local faces = {}
	
    edges = voronoi.fortunes_algorithm(points,0,0,data.length,data.width)
    faces = voronoi.find_faces_from_edges(edges, points)

	if data.show_points == true then
		local point_blocks = {}
		for _,point in pairs(points) do
			local block = pytha.create_block(4,4,4,{point.x-2, point.y-2})
			pytha.set_element_name(block, pyloc "Points")
			table.insert(point_blocks, block)
		end
		local point_group = pytha.create_group(point_blocks, {name = pyloc "Points"})
		table.insert(elements, point_group)
	end

	local areas = {}
    for _,face in ipairs(faces) do
		local polylist = {}
		local seg = {}
		local face_area = area_orientation(face)
		if face_area > 0 then 
			for i=1, #face, 1 do
				table.insert(polylist, {face[i].x, face[i].y})
			end
		elseif face_area < 0 then 
			for i=#face, 1, -1 do
				table.insert(polylist, {face[i].x, face[i].y})
			end
		else 
			goto continue
		end
		local polygon = pytha.create_polygon(polylist)
		pytha.set_element_name(polygon, pyloc "Area")
		table.insert(areas, polygon)
		::continue::	
    end
	local area_group = pytha.create_group(areas, {name = pyloc "Voronoi Areas"})
	table.insert(elements, area_group)

	return elements
end


function recreate_points(data)

	local points = {}
	if data.noise == 1 then
		points = random_points.white_noise(0, data.length, 0, data.width, data.number_points)
	else 
		points = random_points.blue_noise(0, data.length, 0, data.width, 8, data.min_distance)
	end

	return points
end
