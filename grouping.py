from typing import Sequence
from models import Note


def group_notes(notes: Sequence[Note]) -> list[list[Note]]:
    note_groups = []
    used_notes = set()

    def get_identifiers(note: Note):
        identifiers = set()
        if note.email:
            identifiers.add(f"email:{note.email.strip().lower()}")
        if note.telephone:
            identifiers.add(f"tel:{note.telephone.strip()}")
        if note.first_name and note.last_name:
            full_name = f"{note.first_name.strip().lower()}_{note.last_name.strip().lower()}"
            identifiers.add(f"name:{full_name}")
        return identifiers

    for note in notes:
        if note.id in used_notes:
            continue

        group = [note]
        identifiers = get_identifiers(note)
        used_notes.add(note.id)

        for other in notes:
            if other.id in used_notes or other.id == note.id:
                continue

            if identifiers & get_identifiers(other):
                group.append(other)
                used_notes.add(other.id)
                identifiers.update(get_identifiers(other))

        group.sort(key=lambda n: n.created_at, reverse=True)
        note_groups.append(group)

    return note_groups
