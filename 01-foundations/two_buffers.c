#include <stdio.h>
#include <string.h>

void two_buffers(void) {
    char buffer_one [40];
    char buffer_two [60];
    fgets(buffer_one, sizeof(buffer_one), stdin);
    fgets(buffer_two, sizeof(buffer_two), stdin);
    printf("buffer_one: %s\nbuffer_two: %s", buffer_one, buffer_two);
}

int main(void) {
    two_buffers();
    return 0;
}
