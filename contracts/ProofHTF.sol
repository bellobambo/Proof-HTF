// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract ProofSmartContract {
    // Enums
    enum Role {
        TUTOR,
        STUDENT
    }

    struct User {
        string name;
        Role role;
        bool isRegistered;
    }

    struct Course {
        uint256 courseId;
        string title;
        address tutor;
        string tutorName;
        bool isActive;
    }

    struct Exam {
        uint256 examId;
        uint256 courseId;
        string title;
        uint256 questionCount;
        bool isActive;
        address creator;
    }

    struct ExamSession {
        uint256 examId;
        address student;
        uint256[] answers;
        uint256 score;
        bool isCompleted;
    }

    // State Variables
    mapping(address => User) public users;
    mapping(address => bool) public registeredUsers;
    mapping(uint256 => Course) public courses;
    mapping(uint256 => mapping(address => bool)) public courseEnrollments;
    mapping(uint256 => Exam) public exams;
    mapping(uint256 => uint256[]) public courseExams;
    mapping(uint256 => mapping(uint256 => string)) public examQuestions;
    mapping(uint256 => mapping(uint256 => string[4])) public examOptions;
    mapping(uint256 => mapping(uint256 => uint256)) public examCorrectAnswers;
    mapping(uint256 => mapping(address => ExamSession)) public examSessions;

    uint256 public courseCounter;
    uint256 public examCounter;

    // Events
    event UserRegistered(address indexed user, string name, Role role);
    event CourseCreated(uint256 indexed courseId, string title, address indexed tutor);
    event EnrollmentCreated(address indexed student, uint256 indexed courseId);
    event ExamCreated(uint256 indexed examId, uint256 indexed courseId, string title);
    event ExamCompleted(uint256 indexed examId, address indexed student, uint256 score);

    // Modifiers
    modifier onlyTutor() {
        require(registeredUsers[msg.sender] && users[msg.sender].role == Role.TUTOR, "Not a tutor");
        _;
    }

    modifier onlyStudent() {
        require(registeredUsers[msg.sender] && users[msg.sender].role == Role.STUDENT, "Not a student");
        _;
    }

    modifier courseExists(uint256 courseId) {
        require(courseId < courseCounter && courses[courseId].isActive, "Course not found");
        _;
    }

    modifier examExists(uint256 examId) {
        require(examId < examCounter && exams[examId].isActive, "Exam not found");
        _;
    }

    // Core User Management
    function registerUser(string memory name, Role role) public {
        require(!registeredUsers[msg.sender], "Already registered");
        require(bytes(name).length > 0, "Name cannot be empty");

        users[msg.sender] = User({name: name, role: role, isRegistered: true});
        registeredUsers[msg.sender] = true;
        emit UserRegistered(msg.sender, name, role);
    }

    // Core Course Management
    function createCourse(string memory title) public onlyTutor {
        require(bytes(title).length > 0, "Title cannot be empty");

        uint256 courseId = courseCounter;
        courses[courseId] = Course({
            courseId: courseId,
            title: title,
            tutor: msg.sender,
            tutorName: users[msg.sender].name,
            isActive: true
        });

        courseCounter++;
        emit CourseCreated(courseId, title, msg.sender);
    }

    function enrollInCourse(uint256 courseId) public onlyStudent courseExists(courseId) {
        require(!courseEnrollments[courseId][msg.sender], "Already enrolled");
        courseEnrollments[courseId][msg.sender] = true;
        emit EnrollmentCreated(msg.sender, courseId);
    }

    // Core Exam Management
    function createExam(
        uint256 courseId,
        string memory title,
        string[] memory questionTexts,
        string[4][] memory questionOptions,
        uint256[] memory correctAnswers
    ) public onlyTutor courseExists(courseId) {
        require(courses[courseId].tutor == msg.sender, "Not course owner");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(questionTexts.length > 0, "At least one question required");
        require(questionTexts.length == questionOptions.length, "Question-options length mismatch");
        require(questionTexts.length == correctAnswers.length, "Question-answers length mismatch");

        uint256 examId = examCounter;
        exams[examId] = Exam({
            examId: examId,
            courseId: courseId,
            title: title,
            questionCount: questionTexts.length,
            isActive: true,
            creator: msg.sender
        });

        // Store questions, options, and correct answers
        for (uint256 i = 0; i < questionTexts.length; i++) {
            require(bytes(questionTexts[i]).length > 0, "Question text cannot be empty");
            require(correctAnswers[i] < 4, "Correct answer index must be 0-3");

            for (uint256 j = 0; j < 4; j++) {
                require(bytes(questionOptions[i][j]).length > 0, "Option text cannot be empty");
            }

            examQuestions[examId][i] = questionTexts[i];
            examOptions[examId][i] = questionOptions[i];
            examCorrectAnswers[examId][i] = correctAnswers[i];
        }

        courseExams[courseId].push(examId);
        examCounter++;
        emit ExamCreated(examId, courseId, title);
    }

    // Core Assessment System
    function takeExam(uint256 examId, uint256[] memory answers) public onlyStudent examExists(examId) returns (uint256) {
        Exam storage exam = exams[examId];
        require(courseEnrollments[exam.courseId][msg.sender], "Not enrolled in course");

        // Return previous score if exam already completed
        if (examSessions[examId][msg.sender].isCompleted) {
            return examSessions[examId][msg.sender].score;
        }

        require(answers.length == exam.questionCount, "Answer count mismatch");

        // Validate answer indices
        for (uint256 i = 0; i < answers.length; i++) {
            require(answers[i] < 4, "Answer index must be 0-3");
        }

        // Calculate score
        uint256 correctAnswers = 0;
        for (uint256 i = 0; i < exam.questionCount; i++) {
            if (answers[i] == examCorrectAnswers[examId][i]) {
                correctAnswers++;
            }
        }

        // Store exam session
        examSessions[examId][msg.sender] = ExamSession({
            examId: examId,
            student: msg.sender,
            answers: answers,
            score: correctAnswers,
            isCompleted: true
        });

        emit ExamCompleted(examId, msg.sender, correctAnswers);
        return correctAnswers;
    }

    // Essential View Functions
    function getExamQuestions(uint256 examId)
        public
        view
        examExists(examId)
        returns (string[] memory questionTexts, string[4][] memory questionOptions)
    {
        Exam storage exam = exams[examId];
        questionTexts = new string[](exam.questionCount);
        questionOptions = new string[4][](exam.questionCount);

        for (uint256 i = 0; i < exam.questionCount; i++) {
            questionTexts[i] = examQuestions[examId][i];
            questionOptions[i] = examOptions[examId][i];
        }

        return (questionTexts, questionOptions);
    }

    function getExamResults(uint256 examId, address student)
        public
        view
        examExists(examId)
        returns (uint256 rawScore, uint256[] memory answers, bool isCompleted)
    {
        require(
            msg.sender == student || (registeredUsers[msg.sender] && users[msg.sender].role == Role.TUTOR),
            "Unauthorized access"
        );

        ExamSession storage session = examSessions[examId][student];
        return (session.score, session.answers, session.isCompleted);
    }

    // NEW FUNCTION: Get past exam questions with answers for revision
    function getPastExamForRevision(uint256 examId)
        public
        view
        examExists(examId)
        onlyStudent
        returns (
            string[] memory questionTexts,
            string[4][] memory questionOptions,
            uint256[] memory correctAnswers,
            uint256[] memory studentAnswers,
            bool[] memory isCorrect,
            uint256 studentScore,
            uint256 maxScore
        )
    {
        Exam storage exam = exams[examId];
        ExamSession storage session = examSessions[examId][msg.sender];

        // Check if student is enrolled in the course
        require(courseEnrollments[exam.courseId][msg.sender], "Not enrolled in course");

        // Check if student has completed the exam
        require(session.isCompleted, "Must complete exam before viewing revision");

        // Initialize arrays
        questionTexts = new string[](exam.questionCount);
        questionOptions = new string[4][](exam.questionCount);
        correctAnswers = new uint256[](exam.questionCount);
        studentAnswers = new uint256[](exam.questionCount);
        isCorrect = new bool[](exam.questionCount);
        studentScore = session.score;
        maxScore = exam.questionCount;

        // Populate all data for comprehensive revision
        for (uint256 i = 0; i < exam.questionCount; i++) {
            questionTexts[i] = examQuestions[examId][i];
            questionOptions[i] = examOptions[examId][i];
            correctAnswers[i] = examCorrectAnswers[examId][i];
            studentAnswers[i] = session.answers[i];
            isCorrect[i] = (session.answers[i] == examCorrectAnswers[examId][i]);
        }

        return (
            questionTexts,
            questionOptions,
            correctAnswers,
            studentAnswers,
            isCorrect,
            studentScore,
            maxScore
        );
    }

    // Course Management Enhancements
    function getEnrolledCourses(address student) public view returns (Course[] memory) {
        Course[] memory enrolledCourses = new Course[](courseCounter);
        uint256 count = 0;
        
        for (uint256 i = 0; i < courseCounter; i++) {
            if (courseEnrollments[i][student] && courses[i].isActive) {
                enrolledCourses[count] = courses[i];
                count++;
            }
        }
        
        // Resize array
        Course[] memory result = new Course[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = enrolledCourses[i];
        }
        return result;
    }

    function getTutorCourses(address tutor) public view returns (Course[] memory) {
        Course[] memory tutorCourses = new Course[](courseCounter);
        uint256 count = 0;
        
        for (uint256 i = 0; i < courseCounter; i++) {
            if (courses[i].tutor == tutor && courses[i].isActive) {
                tutorCourses[count] = courses[i];
                count++;
            }
        }
        
        Course[] memory result = new Course[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tutorCourses[i];
        }
        return result;
    }

    // Helper Functions
    function getCourse(uint256 courseId) public view courseExists(courseId) returns (Course memory) {
        return courses[courseId];
    }

    function getExam(uint256 examId) public view examExists(examId) returns (Exam memory) {
        return exams[examId];
    }
}
