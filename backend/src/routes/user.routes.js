import { Router } from 'express';
import userController from '../controllers/user.controller.js';
import authenticate from '../middlewares/auth.js';

const router = Router();

// Semua butuh login
router.use(authenticate);

router.get('/', userController.list);
router.post('/', userController.create);
router.patch('/:id', userController.update);
router.delete('/:id', userController.remove);

export default router;
