@tool
extends MultiMeshInstance3D
class_name FlexibleScatter3D


enum PlacementType { RANDOM, GRID }
enum SaveProportions { DISABLE, XY, XZ, YZ, XYZ }

## The number of instances to generate.
@export_range(0, 10000, 1) var count: int = 100:
    get: return count
    set(value):
        count = value
        _scatter()
        
## Defines the placement type. For [color=white]Placement Type[/color] = [color=orange]Grid[/color] the maximum [color=white]Count[/color] of instances will be trimmed to the size of the grid (depends on [color=white]Grid Step[/color]).
@export_enum("Random", "Grid") var placement_type: int = PlacementType.RANDOM:
    get: return placement_type
    set(value):
        placement_type = value
        notify_property_list_changed()
        _scatter()
        
@export_group("Grid")

## The distance between the instance.
@export var grid_step: float = 5:
    get: return grid_step
    set(value):
        grid_step = value
        _scatter()
        
## Row number for offset.
@export var row_x: int = 2:
    get: return row_x
    set(value):
        row_x = clampi(value, 2, 0xff)
        _scatter()

## Row number for offset.
@export var row_y: int = 2:
    get: return row_y
    set(value):
        row_y = clampi(value, 2, 0xff)
        _scatter()
        
## Offset for the instance.
@export var grid_offset: Vector2 = Vector2.ZERO:
    get: return grid_offset
    set(value):
        grid_offset = Vector2(
            clamp(value.x, -grid_step / 2, grid_step / 2),
            clamp(value.y, -grid_step /2 , grid_step / 2)
        )
        _scatter()

@export_group("General")

## Rotate the instance along the surface normal.
@export var rotation_to_normal: bool = false:
    get: return rotation_to_normal
    set(value):
        rotation_to_normal = value
        _scatter()
        
## [color=orange]true[/color] - instances that do not fall into polygon [color=white]Depth[/color] will not be generated.
@export var generate_only_by_depth: bool = false:
    get: return generate_only_by_depth
    set(value):
        generate_only_by_depth = value
        _scatter()
        
## The physics collision mask that the instances should collide with.
@export_flags_3d_physics var collision_mask: int = 0x1:
    get: return collision_mask
    set(value):
        collision_mask = value
        _scatter()
        
@export_group("Random")

## A seed to feed for the random number generator.
@export_range(0, 10000, 1) var random_seed: int = 0:
    get: return random_seed
    set(value):
        random_seed = value
        _rng.seed = value
        _scatter()

## Applying random parameters to an instance.
@export var use_transformation: bool = true:
    get: return use_transformation
    set(value):
        use_transformation = value
        _scatter()
        
## Link the size vactor to preserve the proportions of the instance.
@export_enum("Disable", "XY", "XZ", "YZ", "XYZ") var save_proportions: int = SaveProportions.DISABLE:
    get: return save_proportions
    set(value):
        save_proportions = value
        _scatter()
        
## The minimum random size for each instance.
@export var min_random_size: Vector3 = Vector3(0.75, 0.75, 0.75):
    get: return min_random_size
    set(value):
        min_random_size = value.clamp(Vector3.ONE * 0.01, Vector3.ONE * 100.0)
        _scatter()
        
## The maximum random size for each instance.
@export var max_random_size: Vector3 = Vector3(1.25, 1.25, 1.25):
    get: return max_random_size
    set(value):
        max_random_size = value.clamp(Vector3.ONE * 0.01, Vector3.ONE * 100.0)
        _scatter()
        
## Rotate each instance by a random amount between
@export var random_rotation: Vector3 = Vector3(0.0, 180.0, 0.0):
    get: return random_rotation
    set(value):
        random_rotation = value.clamp(Vector3.ONE * 0.00, Vector3.ONE * 180.0)
        _scatter()

@export_group("Debug")

## Draws a ray for the point where the instance is placed.
@export var debug_draw: bool = false:
    get: return debug_draw
    set(value):
        debug_draw = value
        _scatter()

## Outputs some data to the console.
@export var debug_print: bool = false:
    get: return debug_print
    set(value):
        debug_print = value
        _scatter()
        
var csg_polygon_3d: CSGPolygon3D:
    set(value):
        csg_polygon_3d = value
        _scatter()

@onready var _space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
var _polygon: PackedVector2Array
var _depth: float
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
    if Engine.is_editor_hint():
        if multimesh == null:
            multimesh = MultiMesh.new()
            multimesh.transform_format = MultiMesh.TRANSFORM_3D
        
func _ready() -> void:
    if Engine.is_editor_hint():
        _create_csg_polygon()
        _ensure_correctness()
        _scatter()
        
        var timer: Timer = Timer.new()
        timer.wait_time = 1
        timer.one_shot = false
        timer.timeout.connect(_custom_process)
        add_child(timer)
        timer.start()
        
    else:
        for child: Node in get_children():
            child.queue_free()
        self.set_script(null)

func _notification(what: int) -> void:
    if !is_inside_tree():
        return

    if what == NOTIFICATION_TRANSFORM_CHANGED:
        _scatter()

func _validate_property(property: Dictionary) -> void:
    match property.name:
        'grid_offset', 'grid_step', 'row_x', 'row_y':
            match placement_type:
                PlacementType.RANDOM:
                    property.usage = PROPERTY_USAGE_NO_EDITOR
                PlacementType.GRID:
                    property.usage = PROPERTY_USAGE_DEFAULT
        
func _create_csg_polygon() -> void:
    if csg_polygon_3d:
        return
    
    for child: Node in get_children():
        if child is CSGPolygon3D:
            csg_polygon_3d = child
            return
        
    csg_polygon_3d = CSGPolygon3D.new()
    csg_polygon_3d.polygon = PackedVector2Array([
        Vector2(-20, -20), Vector2(20, -20),
        Vector2(20, 20), Vector2(-20, 20)
    ])
    csg_polygon_3d.depth = 20
    csg_polygon_3d.layers = 0
    csg_polygon_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    csg_polygon_3d.mode = CSGPolygon3D.MODE_DEPTH
    add_child(csg_polygon_3d, true)
    
    csg_polygon_3d.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
    update_configuration_warnings()
        
func _create_default_mesh() -> void:
    if multimesh.mesh:
        return
    
    var box_mesh: BoxMesh = BoxMesh.new()
    box_mesh.size = Vector3(1, 1, 1)
    multimesh.mesh = box_mesh

func _ensure_correctness() -> void:
    if not csg_polygon_3d:
        return
    
    if rotation_degrees != Vector3.ZERO:
        rotation_degrees = Vector3.ZERO
        
    csg_polygon_3d.position = Vector3.ZERO
    csg_polygon_3d.rotation_degrees = Vector3(-90, 0, 0)
    csg_polygon_3d.scale = Vector3.ONE
    
    if not csg_polygon_3d.get_parent():
        csg_polygon_3d.queue_free()
            
func _custom_process() -> void:
    #print('custom_process')
    _create_csg_polygon()
    _ensure_correctness()
    
    if _polygon != csg_polygon_3d.polygon or _depth != csg_polygon_3d.depth:
        _scatter()
        
func _get_random_point_in_polygon() -> Vector2:
    if _polygon.size() < 3:
        return Vector2.ZERO
    
    var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(_polygon)
    if triangles.is_empty():
        return Vector2.ZERO
    
    var total_area: float = 0.0
    var areas: Array = []
    
    for i: int in range(0, triangles.size(), 3):
        var area: float = _triangle_area(
            _polygon[triangles[i]], 
            _polygon[triangles[i + 1]], 
            _polygon[triangles[i + 2]]
        )
        areas.append(area)
        total_area += area
    
    if total_area <= 0:
        return _polygon[0]
    
    var random_value: float = _rng.randf() * total_area
    var cumulative_area: float = 0.0
    var selected_triangle: int = 0
    
    for i: int in range(areas.size()):
        cumulative_area += areas[i]
        if random_value <= cumulative_area:
            selected_triangle = i
            break
    
    var idx: int = selected_triangle * 3
    var v1: Vector2 = _polygon[triangles[idx]]
    var v2: Vector2 = _polygon[triangles[idx + 1]]
    var v3: Vector2 = _polygon[triangles[idx + 2]]
    
    var point: Vector2 = _random_point_in_triangle(v1, v2, v3)
    
    return  point * Vector2(1, -1)
    
func _get_grid_points_in_polygon() -> Array[Vector2]:
    var grid_points: Array[Vector2] = []
    
    if _polygon.size() < 3:
        return grid_points
    
    var min_x: float = _polygon[0].x
    var max_x: float = _polygon[0].x
    var min_y: float = _polygon[0].y
    var max_y: float = _polygon[0].y
    
    for point: Vector2 in _polygon:
        min_x = min(min_x, point.x)
        max_x = max(max_x, point.x)
        min_y = min(min_y, point.y)
        max_y = max(max_y, point.y)
    
    var start_x: float = min_x + grid_step
    var start_y: float = min_y + grid_step
    
    var row: int = 0
    var y: float = start_y
    
    while y <= max_y:
        var col: int = 0
        var x: float = start_x
        
        var x_offset: float = 0.0
        if row % row_x == 1:
            x_offset = grid_offset.x
        
        while x + x_offset <= max_x:
            var y_offset: float = 0.0
            if col % row_y == 1:
                y_offset = grid_offset.y
            
            var point: Vector2 = Vector2(x + x_offset, y + y_offset)
            
            if Geometry2D.is_point_in_polygon(point, _polygon):
                grid_points.append(point * Vector2(1, -1))
            
            x += grid_step
            col += 1
            
        y += grid_step
        row += 1
        
    if count > grid_points.size():
        count = grid_points.size()
    else:
        grid_points.resize(count)
    
    return grid_points

func _triangle_area(v1: Vector2, v2: Vector2, v3: Vector2) -> float:
    return 0.5 * abs((v2.x - v1.x) * (v3.y - v1.y) - (v3.x - v1.x) * (v2.y - v1.y))

func _random_point_in_triangle(v1: Vector2, v2: Vector2, v3: Vector2) -> Vector2:
    var r1: float = _rng.randf()
    var r2: float = _rng.randf()
    
    if r1 + r2 > 1.0:
        r1 = 1.0 - r1
        r2 = 1.0 - r2
    
    return v1 + r1 * (v2 - v1) + r2 * (v3 - v1)

func _apply_random(t: Transform3D, origin: Vector3) -> Transform3D:
    if use_transformation:
        var size_x: float = _rng.randf_range(min_random_size.x, max_random_size.x)
        var size_y: float = _rng.randf_range(min_random_size.y, max_random_size.y)
        var size_z: float = _rng.randf_range(min_random_size.z, max_random_size.z)
        
        match save_proportions:
            SaveProportions.XY:
                var average: float = (size_x + size_y) / 2.0
                size_x = average
                size_y = average
                
            SaveProportions.XZ:
                var average: float = (size_x + size_z) / 2.0
                size_x = average
                size_z = average
                
            SaveProportions.YZ:
                var average: float = (size_y + size_z) / 2.0
                size_y = average
                size_z = average
                
            SaveProportions.XYZ:
                var average: float = (size_x + size_y + size_z) / 3.0
                size_x = average
                size_y = average
                size_z = average
        
        t = t\
            .rotated_local(
                Vector3.RIGHT,
                deg_to_rad(_rng.randf_range(-random_rotation.x, random_rotation.x)))\
            .rotated_local(
                Vector3.UP, 
                deg_to_rad(_rng.randf_range(-random_rotation.y, random_rotation.y)))\
            .rotated_local(
                Vector3.FORWARD, 
                deg_to_rad(_rng.randf_range(-random_rotation.z, random_rotation.z)))\
            .scaled_local(Vector3(size_x, size_y, size_z))
        
        t.origin = origin
        
    return t

func _generate_instance(points: Array[Vector2]) -> void:
    for i: int in range(points.size()):
        var start_v3: Vector3 = Vector3(points[i].x, 0, points[i].y)
        var end_v3: Vector3 = start_v3 + Vector3(0, -csg_polygon_3d.depth, 0)
        
        # A separate, very convenient addon - DebugDraw3D
        #if debug_draw:
            #DebugDraw3D.draw_line(to_global(start_v3), to_global(end_v3), Color.RED, 5)
        
        if debug_print:
            print()
            print('obj global position: ', global_position)
            print('start v3 local: ', start_v3)
            print('start v3 global: ', to_global(start_v3))
            
        var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
            to_global(start_v3), 
            to_global(end_v3), 
            collision_mask
        )
        var hit: Dictionary = _space.intersect_ray(ray)
        var t: Transform3D
        
        if debug_print:
            print('hit: ', hit)
        
        if hit:
            if debug_print:
                print('hit position global: ', hit.position)
                print('hit position local: ', to_local(hit.position))

            t = Transform3D(
                Basis.IDENTITY,
                to_local(hit.position)
            )
            
            if rotation_to_normal:
                if abs(-hit.normal.dot(Vector3.UP)) < 0.9999:  # Не коллинеарны
                    t = t.looking_at(t.origin + hit.normal, Vector3.UP, true)
                    t = t.rotated_local(Vector3.RIGHT, deg_to_rad(90))

            t = _apply_random(t, hit.position - global_position)
            
        else:
            if generate_only_by_depth:
                continue
                
            t = Transform3D(
                Basis.IDENTITY,
                Vector3(points[i].x, 0, points[i].y)
            )
            t = _apply_random(
                t, 
                to_global(Vector3(points[i].x, 0, points[i].y)) - global_position
            )
                    
        multimesh.set_instance_transform(i, t)

func _scatter() -> void:
    if not Engine.is_editor_hint():
        return
        
    _polygon = csg_polygon_3d.polygon
    _depth = csg_polygon_3d.depth
    
    if _polygon.size() < 3:
        return
        
    _create_default_mesh()
    
    _rng.state = 0
    _rng.seed = random_seed
    
    multimesh.instance_count = 0
    multimesh.instance_count = count
    
    var points: Array[Vector2] = []
    
    match placement_type:
        PlacementType.RANDOM:
            for i: int in range(count):
                points.append(_get_random_point_in_polygon())
        
        PlacementType.GRID:
            points = _get_grid_points_in_polygon()
            
    _generate_instance(points)
