--[[
    Random Point Generation module of the luaFortune library.

    Documentation and License can be found here:
    https://bitbucket.org/Jmaa/luafortune
--]]

random_points = {
    version = 1.3,
    default_rnd_func = math.random
}

local TAU = math.pi*2

--------------------------------------------------------------------------------
-- Point object

local point_mt = {
    __tostring = function (t) return "("..t.x..","..t.y..")" end
}

local function new_point (x,y)
    return setmetatable({x=x,y=y},point_mt)
end


local function point_within_polygon (x, y, polygon)
    local result = false
    for i=#polygon, 1, -1 do
        local p2, p1 = polygon[i], i>1 and polygon[i-1] or polygon[#polygon]
        if ((p1.y>y)~=(p2.y>y)) and (x<(p2.x-p1.x)*(y-p1.y)/(p2.y-p1.y)+p1.x) then
            result = not result
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Misc. functions

function point_within_rectangle (px, py, min_x, max_x, min_y, max_y)
    return min_x <= px and px <= max_x and min_y <= py and py <= max_y
end

local function is_point_too_near_other_points (x, y, points, radius_2)
    for _, other_point in ipairs(points) do
        if  (x-other_point.x) ^ 2 + (y-other_point.y) ^ 2 < radius_2 then
            return true
        end
    end
    return false
end

local function get_max_and_min_of_polygon (polygon)
    local min_x, max_x, min_y, max_y = 0, 0, 0, 0
    for _, point in ipairs(polygon) do
        if point.x < min_x then
            min_x = point.x
        end
        if point.x > max_x then
            max_x = point.x
        end
        if point.y < min_y then
            min_y = point.y
        end
        if point.y > min_y then
            max_y = point.y
        end
    end
    return min_x, max_x, min_y, max_y
end

local function get_center_of_polygon (polygon)
    -- It won't return the proper centroid of the polygon. But this will mostly
    -- work alright.
    local total_x, total_y = 0, 0
    for _, point in ipairs(polygon) do
        total_x, total_y = total_x+point.x, total_y+point.y
    end
    return total_x/#polygon, total_y/#polygon
end

--------------------------------------------------------------------------------

random_points.white_noise = function (min_x, max_x, min_y, max_y, nr_points, rnd_func)
    local rnd_func = rnd_func or random_points.default_rnd_func
    local points = {}
    local width, height = max_x - min_x, max_y - min_y
    for i=1, nr_points do
        table.insert(points, new_point(min_x+rnd_func()*width, min_y+rnd_func()*height))
    end
    return points
end

random_points.white_noise_polygon = function (polygon, nr_points, rnd_func)
    local rnd_func = rnd_func or random_points.default_rnd_func
    local points = {}
    local min_x, max_x, min_y, max_y = get_max_and_min_of_polygon(polygon)
    local width, height = max_x - min_x, max_y - min_y
    while #points < nr_points do
        local new_x, new_y = min_x+rnd_func()*width, min_y+rnd_func()*height
        if point_within_polygon (new_x, new_y, polygon) then
            table.insert(points, new_point(new_x, new_y))
        end
    end
    return points
end

local function arbi_blue_noise (point_cond, start_point, missed_points, min_dist, rnd_func)
    local points = {start_point}
    local radius_2, cos, sin = min_dist*min_dist, math.cos, math.sin
    local previous_point, index, misses = points[1], 1, -missed_points

    while true do
        local new_d, new_a = min_dist+rnd_func()*min_dist, rnd_func()*TAU
        local new_x = previous_point.x+cos(new_a)*new_d
        local new_y = previous_point.y+sin(new_a)*new_d

        if not is_point_too_near_other_points(new_x, new_y, points, radius_2)
                and point_cond(new_x, new_y) then
            table.insert(points, new_point(new_x,new_y))
        else
            if misses >= missed_points then
                if index == #points then
                    break
                end
                index, misses = index + 1, 0
                previous_point = points[index]
            end
            misses = misses + 1
        end
    end

    return points
end

random_points.blue_noise = function (min_x, max_x, min_y, max_y, missed_points, min_dist, rnd_func)
    local rnd_func = rnd_func or random_points.default_rnd_func
    local start_point = new_point(min_x + rnd_func() * (max_x - min_x),
                                  min_y + rnd_func() * (max_y - min_y))

    local condition = function (x, y)
        return point_within_rectangle(x, y, min_x, max_x, min_y, max_y)
    end

    return arbi_blue_noise(condition, start_point, missed_points, min_dist, rnd_func)
end

random_points.blue_noise_polygon = function (polygon, missed_points, min_dist, rnd_func)
    local rnd_func = rnd_func or random_points.default_rnd_func
    local start_point = new_point(get_center_of_polygon(polygon))
    local condition = function (x, y)
        return point_within_polygon(x, y, polygon)
    end

    return arbi_blue_noise(condition, start_point, missed_points, min_dist, rnd_func)
end

--------------------------------------------------------------------------------
