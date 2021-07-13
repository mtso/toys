#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct DoublyLinkedList
{
    struct Node* head;
    struct Node* tail;
    int len;
};

struct Node
{
    char* data;               // integer data
    struct Node* next;      // pointer to the next node
    struct Node* prev;
};

// Helper function in C to return new linked list node from the heap
struct Node* newNode(char* data)
{
    // allocate a new node in a heap using `malloc()` and set its data
    struct Node* node = (struct Node*)malloc(sizeof(struct Node));
    node->data = data;
 
    // set the `.next` pointer of the new node to point to null
    node->next = NULL;
    node->prev = NULL;
 
    return node;
}

int indexOfNode(struct DoublyLinkedList* list, const char* needle)
{
    int index = 0;
    struct Node* curr = list->head;
    while (curr)
    {
        if (0 == strcmp(curr->data, needle))
        {
            return index;
        }

        index += 1;
        curr = curr->next;
    }

    return -1;
}

void appendNode(struct DoublyLinkedList* list, struct Node* node)
{
    if (list->tail)
    {
        list->tail->next = node;
        node->prev = list->tail;
        list->tail = node;
    }
    else
    {
        list->tail = node;
    }
    if (!list->head)
    {
        list->head = node;
    }
    list->len += 1;
}

// head a
// tail b
// a<->b
// head a, tail a
// a
void removeLastNode(struct DoublyLinkedList* list)
{
    if (list->tail)
    {
        struct Node* to_remove = list->tail;
        if (list->tail->prev)
        {
            list->tail = list->tail->prev;
            list->tail->next = NULL;
        }
        else
        {
            list->tail = NULL;
            list->head = NULL;
        }
        free(to_remove);
        list->len -= 1;
    }
}

struct DoublyLinkedList* newList()
{
    struct DoublyLinkedList* list = (struct DoublyLinkedList*)malloc(sizeof(struct DoublyLinkedList));
    list->head = NULL;
    list->tail = NULL;
    return list;
}

void emptyList(struct DoublyLinkedList* list)
{
    while (list->len > 0)
    {
        removeLastNode(list);
    }
}

void printList(struct DoublyLinkedList* list)
{
    struct Node* ptr = list->head;
    while (ptr)
    {
        printf("%s", ptr->data);
        if (ptr->next)
        {
            printf("<->");
        }
        ptr = ptr->next;
    }
    printf("\n");
}

void printListRev(struct DoublyLinkedList* list)
{
    struct Node* ptr = list->tail;
    while (ptr)
    {
        printf("%s", ptr->data);
        if (ptr->prev)
        {
            printf("<->");
        }
        ptr = ptr->prev;
    }
    printf("\n");
}

int main(void)
{
    struct DoublyLinkedList* list = newList();
    struct Node* node1 = newNode("hello");
    appendNode(list, node1);
    appendNode(list, newNode("world"));
    appendNode(list, newNode("!"));

    printf("list size %d\n", list->len);
    int loc = indexOfNode(list, "world");
    printf("index of world: %d\n", loc);
    printList(list);
    emptyList(list);
    printf("list size %d\n", list->len);

    printList(list);

    // struct Node* node = newNode("hello");
    // `head` points to the first node (also known as a head node) of a linked list
    // struct Node* head = constructList();
 
    // print linked list
    // printList(head);

    // printf("Hello, World! %lu\n", strlen(node->data));
 
    return 0;
}
