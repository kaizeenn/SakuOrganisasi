import { Router } from 'express';
import eventController from '../controllers/event.controller.js';
import authenticate from '../middlewares/auth.js';

const router = Router();

router.use(authenticate);

router.get('/', eventController.list);
router.get('/:id', eventController.get);
router.post('/', eventController.create);
router.patch('/:id', eventController.update);
router.delete('/:id', eventController.remove);

export default router;
