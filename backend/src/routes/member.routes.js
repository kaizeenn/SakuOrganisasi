import { Router } from 'express';
import memberController from '../controllers/member.controller.js';
import authenticate from '../middlewares/auth.js';

const router = Router();

router.use(authenticate);

router.get('/', memberController.list);
router.get('/:id', memberController.get);
router.post('/', memberController.create);
router.patch('/:id', memberController.update);
router.delete('/:id', memberController.remove);

export default router;
