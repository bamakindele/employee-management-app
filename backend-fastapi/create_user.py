
from getpass import getpass

from sqlalchemy import select

from main import Base, SessionLocal, User, engine
from werkzeug.security import generate_password_hash

Base.metadata.create_all(engine)

username = input("New username: ").strip()
password = getpass("New password (minimum 6 characters): ")

if not username or len(password) < 6:
    raise SystemExit("Enter a username and a password of at least 6 characters.")

with SessionLocal() as db:
    existing = db.scalar(
        select(User).where(User.username == username)
    )
    if existing:
        raise SystemExit("That username already exists.")

    db.add(User(
        username=username,
        password_hash=generate_password_hash(password),
    ))
    db.commit()

print("Login account created.")
