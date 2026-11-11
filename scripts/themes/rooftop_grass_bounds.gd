extends RefCounted
## Shared contract for the grass vertex program and its conservative CPU envelope.
## Approved shells reach less than 0.075 world units; larger edits stay bounded.
const MAX_OFFSET := 0.25

static func vertex_code() -> String:
 return "void vertex() {\n VERTEX.y+=clamp(shell_height,-%s,%s);\n}" % [MAX_OFFSET, MAX_OFFSET]
