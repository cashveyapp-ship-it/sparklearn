// Simply re-export from the service â€” the provider is defined there.
// Having it in two places caused a duplicate provider conflict.
export '../services/ai_tutor_service.dart'
    show AiTutorService, aiTutorServiceProvider;
