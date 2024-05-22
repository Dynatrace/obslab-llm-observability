/* A demo travel guide built on top of OpenAI.
*/
const http = require('http');
const https = require('https');
var url = require('url');
const OpenAI = require('openai');

const { default: weaviate } = require('weaviate-ts-client');

const { createLogger, format, transports } = require('winston');
const { combine, timestamp, label, json } = format;

const logger = createLogger({
  level: 'info',
  format: combine(
    timestamp(),
    json()
  ),
  defaultMeta: { service: 'travel-advisor' },
  transports: [new transports.Console()],
});

const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;

var COMPLETION_LENGTH = 20; // the default completion length in tokens
if(process.env.COMPLETION_LENGTH) {
  COMPLETION_LENGTH = parseInt(process.env.COMPLETION_LENGTH, 10);
} 

/* ------- Semantic cache functions ---------- */

create_cache_collection('Travel') 

/* Create a cache collection.
*/
async function create_cache_collection(collection_name) {
  if(process.env.WEAVIATE_ENDPOINT) {
    try {
      const client = weaviate.client({
        scheme: 'http',
        host: process.env.WEAVIATE_ENDPOINT
      });
      
      const classWithProps = {
        class: 'Travel',
        properties: [
          {
            name: 'prompt',
            dataType: ['text'],
          },
          {
            name: 'answer',
            dataType: ['text'],
          },
          {
            name: 'creation_timestamp',
            dataType: ['text'],
          },
        ],
      };
      
      // Add the class to the schema
      result = await client
        .schema
        .classCreator()
        .withClass(classWithProps)
        .do();
      logger.info("Weaviate collection created.");
    } catch (ex) {
      logger.info("Weaviate collection already exists.");
    }
  }
}

/* Cache a given prompt along with its embedding and answer.
*/
async function cache_completion(prompt, prompt_vector, answer) {
  if(process.env.WEAVIATE_ENDPOINT) {
    const client = weaviate.client({
      scheme: 'http',
      host: process.env.WEAVIATE_ENDPOINT
    });
    result = await client.data
      .creator()
      .withClassName('Travel')
      .withProperties({
        prompt: prompt,
        answer: answer,
        creation_timestamp: Date.now().toString()
      }).withVector(prompt_vector)
      .do();
  }
}

/* Try to retrieve an answer by searching similar prompts in a semantic cache.
*/
async function get_cached_prompt(vector) {
  if(process.env.WEAVIATE_ENDPOINT) {
    const maxDistance = 0.01;
    const client = weaviate.client({
      scheme: 'http',
      host: process.env.WEAVIATE_ENDPOINT
    });

    result = await client.graphql
      .get()
      .withClassName('Travel')
      .withNearVector({ 
        vector: vector,
        distance: maxDistance,
        limit: 1 
      })
      .withFields('answer prompt creation_timestamp')
      .withLimit(1)
      .do();
    return result;
  }
}

/* Checks if the cached value is outdated according to the cache_minutes setting. 
*/
function cacheOutdated(timestamp_str) {
  const delta_mins = (Date.now() - parseInt(timestamp_str, 10))/1000/60;
  if(process.env.CACHE_MINUTES && (delta_mins > parseInt(process.env.CACHE_MINUTES, 10))) {
      return true;
  } else {
    // if no cache_minutes is set, 60 minutes is used as default
    if(delta_mins > 60) { 
      return true;
    }
  }
  return false; 
}

/* ------- LLM functions ---------- */

/* Get the completion from one of the configured LLM cloud services.
 */
async function get_completion(prompt) {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });
  try {
    const chatCompletion = await openai.chat.completions.create({
      messages: [{ role: "user", content: "Give travel advise in a paragraph of max " + COMPLETION_LENGTH + " words about " + w}],
      model: "gpt-3.5-turbo",
    });
    // Return the completion message as JSON
    const jsonData = {
      message: chatCompletion.choices[0].message.content
    };
    // important info log for extracting token counts on the Dynatrace side
    logger.info(chatCompletion);
    return jsonData;
  } catch(e) {
    logger.error(e);
    // in case of error, return an empty message
    emptyMsg = {
      message: ""
    };
    return emptyMsg
  }
}

/* Returns the embedding vector for the given prompt text for the purpose of storing it in a semantic cache.
 */
async function get_embedding_vector(text) {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });
  var input = {
    model: 'text-embedding-ada-002',
    input: text,
  }
  try {
    response = await openai.embeddings.create(input);
    // important log for extracting token counts on the Dynatrace side
    logger.info({'model' : response.model, 'usage' : response.usage });
    return response?.data[0].embedding;
  } catch(e) {
    logger.error(e);
    return null;
  }
}

// Set the "public" folder as the static folder
app.use(express.static(path.join(__dirname, 'public')));

// Define routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/api/v1/completion', async (req, res) => {
    // Extract the 'prompt' query parameter from the request URL
    const promtValue = req.query.prompt;
    cacheHit = false;
    if(promtValue) {
      w = promtValue.trim().toLowerCase();
      if(w.length > 0 && w.length < 50) {
        // create embedding vector
        if(process.env.WEAVIATE_ENDPOINT) {
          emb_vector = await get_embedding_vector(w);
          if(emb_vector) {
            // check if prompt is already cached in the semantic cache   
            result = await get_cached_prompt(emb_vector);
            logger.info("Result from get_cached_prompt: " + result);
            if(result.data.Get.Travel.length > 0 && !cacheOutdated(result.data.Get.Travel[0].creation_timestamp)) { // cache hit
              res.json({ "message" : result.data.Get.Travel[0].answer});
            } else { // no cache entry, generate a new completion
              // Send the JSON data as the response
              advise = await get_completion(w);
              // store the answer in semantic cache
              cache_completion(w, emb_vector, advise.message) 
              // return the answer
              res.json(advise);
            }
          } else {
            logger.error("OpenAI embedding creation failed!");
            res.json({ "message" : ""});
          }
        } else {
          // Send the JSON data as the response
          advise = await get_completion(w);
          // return the answer
          res.json(advise);
        }
      } else {
          res.json({ "message" : "No idea."});
      }
    }
});

app.get('/favicon.ico', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'favicon.ico'));
});

app.get('/api/v1/thumbsUp', (req, res) => {
  logger.info("Positive user feedback");
});

app.get('/api/v1/thumbsDown', (req, res) => {
  logger.info("Negative user feedback");
});

app.use('/images', express.static('public/images'))

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});