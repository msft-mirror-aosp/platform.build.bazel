#include "llhttp.h"
#include <assert.h>
#include <string.h>

static int on_message_complete(llhttp_t* parser) {
    (void)parser;
    return 0;
}

int main(void) {
    llhttp_t parser;
    llhttp_settings_t settings;

    llhttp_settings_init(&settings);
    settings.on_message_complete = on_message_complete;

    llhttp_init(&parser, HTTP_REQUEST, &settings);

    const char* request = "GET /status HTTP/1.1\r\nHost: localhost\r\n\r\n";
    llhttp_errno_t err = llhttp_execute(&parser, request, strlen(request));
    assert(err == HPE_OK);
    return 0;
}
