use "std/db/mysql" as db

let CONN_STR = "mysql://quest:quest_password@localhost:6603/quest_test"

let conn = db.connect(CONN_STR)
let cursor = conn.cursor()

# Test with a simple NOW() query
cursor.execute("SELECT NOW() as now_time, CURDATE() as cur_date, CURTIME() as cur_time")
let rows = cursor.fetch_all()

puts("Row: ", rows[0])
puts("now_time cls: ", rows[0].get("now_time").cls())
puts("cur_date cls: ", rows[0].get("cur_date").cls())
puts("cur_time cls: ", rows[0].get("cur_time").cls())

conn.close()
