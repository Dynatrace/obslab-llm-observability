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

const { trace, SpanStatusCode } = require('@opentelemetry/api');
const tracer = trace.getTracer('traveladvisor', '0.1.0');

var COMPLETION_LENGTH = 20; // the default completion length in tokens
if(process.env.COMPLETION_LENGTH) {
  COMPLETION_LENGTH = parseInt(process.env.COMPLETION_LENGTH, 10);
}

const AI_MODEL = process.env.ai_model || 'gpt-3.5-turbo';
const AI_SYSTEM = 'openai';
const AI_EMBEDDING_MODEL = 'text-embedding-ada-002';

/* Temporary until LLM Semantic conventions
 *  are released: https://github.com/traceloop/semantic-conventions/blob/4ee7433cd9bbda00bca0f118c1230ff13eac62e5/docs/gen-ai/llm-spans.md
 * Use these as keys. For example:
 * span.setAttribute(SEMCONV_TMP_GENAI_SYSTEM: "openai");
 */
// Required
const SEMCONV_TMP_GENAI_REQUEST_MODEL = "gen_ai.request.model";                      // eg. "gpt-4"
const SEMCONV_TMP_GENAI_SYSTEM = "gen_ai.system";                                    // eg, "openai"

// Recommended
const SEMCONV_TMP_GENAI_REQUEST_MAX_TOKENS = "gen_ai.request.max_tokens";            // eg. 100
const SEMCONV_TMP_GENAI_REQUEST_TEMPERATURE = "gen_ai.request.temperature";          // eg. 0.0
const SEMCONV_TMP_GENAI_REQUEST_TOP_P = "gen_ai.request.top_p";                      // eg. 1.0
const SEMCONV_TMP_GENAI_REQUEST_FINISH_REASONS = "gen_ai.request.finish_reasons";    // eg. ["stop"]
const SEMCONV_TMP_GENAI_RESPONSE_ID = "gen_ai.response.id";                          // eg. "chatcmpl-123"
const SEMCONV_TMP_GENAI_RESPONSE_MODEL = "gen_ai.response.model";                    // eg. "gpt-4-0613"
const SEMCONV_TMP_GENAI_USAGE_COMPLETION_TOKENS = "gen_ai.usage.completion_tokens";  // eg. 180
const SEMCONV_TMP_GENAI_USAGE_PROMPT_TOKENS = "gen_ai.usage.prompt_tokens";          // eg. 100

// My addition
const SEMCONV_GENAI_REQUEST_PROMPT = "gen_ai.request.prompt"; // eg. "Give me destination advice about the city of Sydney"
const SEMCONV_GENAI_RESPONSE = "gen_ai.response.content"; // eg. "Explore the Sydney markets, beautiful beaches and Opera House."

const DEBUG_VERSION = "0.0.1";

/* ------- Semantic cache functions ---------- */

create_cache_collection('Travel') 

/* Create a cache collection.
*/
async function create_cache_collection(collection_name) {
  
  if(process.env.WEAVIATE_ENDPOINT) {
    const span = tracer.startSpan('create_cache_collection', { attributes: { "collection_name": collection_name } });
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
    } // end of catch
    span.end();
  }
}

/* Cache a given prompt along with its embedding and answer.
*/
async function cache_completion(prompt, prompt_vector, answer) {
  if(process.env.WEAVIATE_ENDPOINT) {
    const span = tracer.startSpan('cache_completion');
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
      span.end();
  }
}

/* Try to retrieve an answer by searching similar prompts in a semantic cache.
*/
async function get_cached_prompt(vector) {
  
  if(process.env.WEAVIATE_ENDPOINT) {
    const span = tracer.startSpan('get_cached_prompt');
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
    span.end();
    return result;
  }
}

/* Checks if the cached value is outdated according to the cache_minutes setting. 
*/
function cacheOutdated(timestamp_str) {
  const span = tracer.startSpan('cacheOutdated');
  const delta_mins = (Date.now() - parseInt(timestamp_str, 10))/1000/60;
  if(process.env.CACHE_MINUTES && (delta_mins > parseInt(process.env.CACHE_MINUTES, 10))) {
      span.setAttribute("cache-outdated","true");
      span.end();
      return true;
  } else {
    // if no cache_minutes is set, 60 minutes is used as default
    if(delta_mins > 60) { 
      span.setAttribute("cache-outdated","true");
      span.end();
      return true;
    }
  }
  span.setAttribute("cache-outdated","false");
  span.end();
  return false; 
}

/* ------- LLM functions ---------- */

/* Get the completion from one of the configured LLM cloud services.
 */

async function get_completion(prompt) {
  prompt = "Give travel advise in a paragraph of max " + COMPLETION_LENGTH + " words about " + w;
  // Square brackets print out the value of the constant, rather than literally "SEMCONV_TMP_GENAI_SYSTEM"
  const span = tracer.startSpan('get_completion', { attributes: { [SEMCONV_TMP_GENAI_SYSTEM]: AI_SYSTEM, [SEMCONV_TMP_GENAI_REQUEST_MODEL]: AI_MODEL, [SEMCONV_TMP_GENAI_USAGE_COMPLETION_TOKENS]: COMPLETION_LENGTH, [SEMCONV_GENAI_REQUEST_PROMPT]: prompt } });

  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });
  try {
    const chatCompletion = await openai.chat.completions.create({
      messages: [{ role: "user", content: prompt}],
      model: AI_MODEL,
    });
    // Return the completion message as JSON
    const jsonData = {
      message: chatCompletion.choices[0].message.content
    };
    // important info log for extracting token counts on the Dynatrace side
    logger.info(chatCompletion);
    span.setAttributes({ [SEMCONV_TMP_GENAI_RESPONSE_ID]: chatCompletion.id, [SEMCONV_TMP_GENAI_RESPONSE_MODEL]: chatCompletion.model, [SEMCONV_TMP_GENAI_REQUEST_FINISH_REASONS]: [ chatCompletion.choices[0].finish_reason ], [SEMCONV_GENAI_RESPONSE]: jsonData['message']});
    span.end();
    return jsonData;
  } catch(e) {
    logger.error(e);
    span.recordException(e);
    // in case of error, return an empty message
    emptyMsg = {
      message: ""
    };
    // TODO: Set span status
    span.end();
    return emptyMsg
  }
}


/* Returns the embedding vector for the given prompt text for the purpose of storing it in a semantic cache.
 */
async function get_embedding_vector(text) {

  //const span = tracer.startSpan('get_embedding_vector');
  tracer.startActiveSpan('get_embedding_vector', async (span) => {
      span.setAttributes({ "text": text, [SEMCONV_TMP_GENAI_REQUEST_MODEL]: AI_EMBEDDING_MODEL, "debug_version": DEBUG_VERSION});

      const openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY,
      });
      var input = {
        model: AI_EMBEDDING_MODEL,
        input: text,
      }
      try {
        response = await openai.embeddings.create(input);
        // important log for extracting token counts on the Dynatrace side
        logger.info({'model' : response.model, 'usage' : response.usage });
        span.setAttributes({[SEMCONV_TMP_GENAI_RESPONSE_MODEL]: response.model, "usage": response.usage });
        span.end();
        return response?.data[0].embedding;
      } catch(e) {
        logger.error(e);
        span.recordException(e);
        span.end();
        return null;
      }
    });
}

// Set the "public" folder as the static folder
app.use(express.static(path.join(__dirname, 'public')));

// Define routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/api/v1/completion', async (req, res) => {
  logger.info("Starting Active Span: /api/v1/completion");

  tracer.startActiveSpan('/api/v1/completion', async (span) => {
    // Extract the 'prompt' query parameter from the request URL
    const promptValue = req.query.prompt;
    span.setAttribute("input-destination", promptValue);

    cacheHit = false;
    if(promptValue) {
      w = promptValue.trim().toLowerCase();
      if(w.length > 0 && w.length < 50) {
        // create embedding vector
        if(process.env.WEAVIATE_ENDPOINT) {
          span.setAttribute("using-cache", true);
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
          span.setAttribute("using-cache", false);

          // Send the JSON data as the response
          advise = await get_completion(w);
          // return the answer
          res.json(advise);
        }
      } else {
          span.setStatus(SpanStatusCode.ERROR);
          span.recordException()
          res.json({ "message" : "No idea."});
      }
    }
    span.end();
  })
});

app.get('/favicon.ico', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'favicon.ico'));
});

app.get('/api/v1/thumbsUp', (req, res) => {
  const promptValue = req.query.prompt;
  cleanedPrompt = promptValue.trim().toLowerCase();
  logger.info("Positive user feedback for search term: " + cleanedPrompt);
});

app.get('/api/v1/thumbsDown', (req, res) => {
  const promptValue = req.query.prompt;
  cleanedPrompt = promptValue.trim().toLowerCase();
  logger.info("Negative user feedback for search term: " + cleanedPrompt);
});

app.use('/images', express.static('public/images'))

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
