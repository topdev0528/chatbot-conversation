package com.neomatrix369;

import kong.unirest.HttpResponse;
import kong.unirest.JsonNode;
import kong.unirest.Unirest;

import java.util.*;

/**
 * Hello world!
 */
public class ConnectTheWorlds {
    private static final Map<String, String> Helidon = new HashMap<>() {
        {
            put("url", "http://localhost:9090/message");
            put("response_format", "application/json");
        }
    };

    private static final Map<String, String> Quarkus = new HashMap<>() {
        {
            put("url", "http://localhost:8080/message");
            put("response_format", "application/text");
        }
    };

    private static final Map<String, Map<String, String>> WORLDS =
            new HashMap<>() {
                {
                    put("Helidon", Helidon);
                    put("Quarkus", Quarkus);
                }
            };

    // https://stackoverflow.com/questions/5762491/how-to-print-color-in-console-using-system-out-println
    public static final String WHITE_BRIGHT = "\033[0;97m";
    public static final String WHITE_BOLD_BRIGHT = "\033[1;97m"; // WHITE
    public static final String RED = "\033[0;31m";     // RED
    public static final String BLUE = "\033[0;34m";    // BLUE
    public static final String GREEN = "\033[0;32m";   // GREEN
    public static final String ANSI_RESET = "\u001B[0m";
    public static void main(String[] args) throws InterruptedException {
        List<Map<String, String>> messages_exchanged = new ArrayList<>();

        Map<String, String> each_conversation = new HashMap<>();
        for (;;) {
            for (String firstWorld : WORLDS.keySet()) {
                Map<String, String> world = WORLDS.get(firstWorld);
                String https_url = world.get("url");
                String response_format = world.get("response_format");
                String response_as_string = "";
                String messageFromTheOtherWorld = getMessageFromTheOtherWorld(firstWorld, each_conversation);
                String theOtherWorld = getTheOtherWorld(firstWorld);
                System.out.printf("%s%s => %s%s: %s%n",
                        GREEN, theOtherWorld, firstWorld, ANSI_RESET,
                        messageFromTheOtherWorld);
                if (response_format.toLowerCase().contains("json")) {
                    HttpResponse<JsonNode> response = Unirest
                            .get(https_url + "/" + messageFromTheOtherWorld)
                            .asJson();
                    response_as_string = response.getBody().getObject().getString("message");
                } else {
                    HttpResponse<String> response = Unirest
                            .get(https_url + "/" + messageFromTheOtherWorld)
                            .asString();
                    response_as_string = response.getBody();
                }

                each_conversation.put(firstWorld, response_as_string);

//                System.out.printf("%s answers to %s: %s%n", firstWorld, theOtherWorld, response_as_string);
                System.out.printf("%n");
                Thread.sleep(4000);

                messages_exchanged.add(each_conversation);

            }
        }
    }

    private static String getTheOtherWorld(String world_key) {
        for (String key: WORLDS.keySet()) {
            if (! world_key.equals(key) ) {
                return key;
            }
        }
        return world_key;
    }

    private static String getMessageFromTheOtherWorld(String world_key,
                                                      Map<String, String> each_conversation) {
        for (String key: each_conversation.keySet()) {
            if (! world_key.equals(key) ) {
                return each_conversation.get(key);
            }
        }
        return getRandomGreetingMessage();
    }

    private static String getRandomGreetingMessage() {
        List<String> messages = Arrays.asList(
                "Hello", "How are you today?", "How are things?", "Are you having a good day?"
        );
        Random random = new Random();
        int random_int = random.nextInt(messages.size());
        return messages.get(random_int);
    }
}