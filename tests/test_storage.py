import tempfile
import unittest
from pathlib import Path
from agent.storage import Storage


class StorageTests(unittest.TestCase):
    def test_notes_tasks_and_chat(self):
        with tempfile.TemporaryDirectory() as folder:
            store = Storage(str(Path(folder) / "test.db"))
            store.add_note(1, "hello")
            self.assertEqual(store.notes(1)[0][1], "hello")
            self.assertEqual(store.notes(2), [])
            store.add_task(1, "build bot")
            task_id = store.tasks(1)[0][0]
            self.assertFalse(store.complete_task(2, task_id))
            self.assertTrue(store.complete_task(1, task_id))
            store.add_message(1, "user", "hi")
            self.assertEqual(store.history(1)[0]["content"], "hi")
            store.clear_history(1)
            self.assertEqual(store.history(1), [])


if __name__ == "__main__":
    unittest.main()
