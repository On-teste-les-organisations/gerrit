import static java.util.stream.Collectors.toList;
import com.google.gerrit.reviewdb.server.ReviewDb;
import com.google.gerrit.server.notedb.NotesMigration;
import java.util.stream.Stream;
    PushOneCommit create(ReviewDb db, PersonIdent i, TestRepository<?> testRepo);
        ReviewDb db,
        PersonIdent i,
        TestRepository<?> testRepo,
        @Assisted("changeId") String changeId);
        ReviewDb db,
        ReviewDb db,
        ReviewDb db,
  private final NotesMigration notesMigration;
  private final ReviewDb db;
      NotesMigration notesMigration,
      @Assisted ReviewDb db,
    this(
        notesFactory,
        approvalsUtil,
        queryProvider,
        notesMigration,
        db,
        i,
        testRepo,
        SUBJECT,
        FILE_NAME,
        FILE_CONTENT);
      NotesMigration notesMigration,
      @Assisted ReviewDb db,
        notesMigration,
        db,
      NotesMigration notesMigration,
      @Assisted ReviewDb db,
    this(
        notesFactory,
        approvalsUtil,
        queryProvider,
        notesMigration,
        db,
        i,
        testRepo,
        subject,
        fileName,
        content,
        null);
      NotesMigration notesMigration,
      @Assisted ReviewDb db,
    this(
        notesFactory,
        approvalsUtil,
        queryProvider,
        notesMigration,
        db,
        i,
        testRepo,
        subject,
        files,
        null);
      NotesMigration notesMigration,
      @Assisted ReviewDb db,
        notesMigration,
        db,
      NotesMigration notesMigration,
      ReviewDb db,
    this.db = db;
    this.notesMigration = notesMigration;
      if (notesMigration.readChanges()) {
        assertReviewers(c, ReviewerStateInternal.REVIEWER, expectedReviewers);
        assertReviewers(c, ReviewerStateInternal.CC, expectedCcs);
      } else {
        assertReviewers(
            c,
            ReviewerStateInternal.REVIEWER,
            Stream.concat(expectedReviewers.stream(), expectedCcs.stream()).collect(toList()));
      }
          approvalsUtil.getReviewers(db, notesFactory.createChecked(db, c)).byState(state);