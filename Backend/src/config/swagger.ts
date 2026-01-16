import YAML from 'yamljs';
import path from 'path';

// Load swagger spec from YAML file in project root
export const swaggerSpec = YAML.load(path.join(__dirname, '..', '..', 'swagger.yaml'));
