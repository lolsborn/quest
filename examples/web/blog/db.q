use "std/db/sqlite"
use "std/os"


# Import repositories
use "./repos/user" as user_repo
use "./repos/post" as post_repo
use "./repos/tag" as tag_repo
use "./repos/page" as page_repo
use "./repos/media" as media_repo


# Initialize database connection (reused across requests)
# Configuration - use DB_FILE env var if available
let db_file = os.getenv("DATABASE_URL") or "blog.sqlite3"
let conn = sqlite.connect(db_file)
let db = conn.cursor()

pub fun get_db()
    return db
end

pub let user = user_repo
pub let post = post_repo
pub let tag = tag_repo
pub let page = page_repo
pub let media = media_repo
